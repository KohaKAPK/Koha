#!/usr/bin/perl

# Copyright (C) 2014-2015 by Jacek Ablewicz
# Copyright (C) 2014-2015 by Rafal Kopaczka
# Copyright (C) 2014-2015 by Krakowska Akademia im. Andrzeja Frycza Modrzewskiego
#
# This file is part of Koha.
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

=head1 NAME

inventory_books_definitions.pl

=head1 SYNOPSIS

Script for adding, modifying and deleting accession|inventory|writeoff
book definitions.

=cut

use Modern::Perl;

use CGI;
use C4::Context;
use C4::Auth;
use C4::Dates qw(format_date);
use C4::Output;
use C4::Inventory;
use C4::Members;
## use Date::Calc qw/Today/;

my $query = CGI->new;
my ( $template, $loggedinuser, $cookie, $userflags ) = get_template_and_user(
    {   template_name   => 'inventory/inventory_books_definitions.tt',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { inventory => '*' }, ## FIXME
    }
);

my $op = $query->param('op') || 'else';
my $op_error = '';
my $op_success = '';
my $booktype = $query->param('ae_type') || '';
my $bookid = $query->param('invbook_definition_id') || undef;

$template->param(
    script_name => '/cgi-bin/koha/inventory/inventory_books_definitions.pl',
);

{
    $op eq 'add_form' || last;
    $template->param(
        $op => 1,
        ae_type => $booktype,
        UnassociatedBooksAvailable => _GetUnassociatedBooksForType($booktype),
        ae_writeoff_basis_seq_number_last => 0,
    );
}

{
    $op eq 'edit_form' || last;
    my $bookdef = GetInvBookDefDetails( $bookid );
    $bookdef || do {
        $op = 'else';
        last;
    };
    my @FL = qw(
        name name_abbrev bookcode type branchcode owned_by active
        print_format display_format numbering_format date_start_of_numbering
        notes timestamp_updated
        cn_prefix cn_suffix default_location
        number_prefix number_suffix
        writeoff_basis_seq_number_last writeoff_parent_invbook_defn_id

        date_start_of_numbering page_number_last entry_nuber_last
        total_items total_cost
    );
    for my $fld (@FL) {
        $template->param( 'ae_'.$fld => $bookdef->{$fld} );
    }

    $bookdef->{entries_total_cost} = sprintf('%.02f',($bookdef->{entries_total_cost} || 0));
    $template->param(
        invbook_definition_id => $bookdef->{invbook_definition_id},
        ae_owner_name => _GetOwnerName($bookdef->{owned_by}),
        UnassociatedBooksAvailable => _GetUnassociatedBooksForType($bookdef->{type}, $bookdef->{writeoff_parent_invbook_defn_id}),
        $op => 1,
        bookdef => $bookdef,
    );
}

{
    ## save from edit_form
    ($op eq 'save' && $bookid) || last;
    my $bookdef = GetInvBookDef( $bookid );
    $bookdef || do {
        $op = 'else'; $op_error = 'edit'; last;
    };
    my @FL = qw(
        name name_abbrev branchcode owned_by active
        print_format display_format numbering_format notes
        number_prefix number_suffix
    );
    push (@FL, (($bookdef->{'type'} eq 'I')? ('cn_prefix', 'cn_suffix', 'default_location', 'writeoff_parent_invbook_defn_id'): () ));
    push (@FL, (($bookdef->{'type'} eq 'W')? ('writeoff_basis_seq_number_last', 'writeoff_parent_invbook_defn_id'): () ));

    my $modbd = { invbook_definition_id => $bookid };
    for my $fld (@FL) {
        my $value = $query->param('ae_'.$fld);
        $modbd->{$fld} = $value;
    }

    my $result = ModInvBookDef( $modbd );
    ($result && $result ne "0E0") || do {
        $op = 'else'; $op_error = 'edit'; last;
    };
    $op_success = 'edit';
    $op = 'else';
}

{
    ## save from add_form
    ($op eq 'save' && !$bookid && $booktype ne '') || last;
    my @FL = qw(
        type bookcode name name_abbrev branchcode active
        print_format display_format numbering_format notes
        number_prefix number_suffix
    );
    push (@FL, (($booktype eq 'I')? ('cn_prefix', 'cn_suffix', 'default_location', 'writeoff_parent_invbook_defn_id'): () ));
    push (@FL, (($booktype eq 'W')? ('writeoff_basis_seq_number_last', 'writeoff_parent_invbook_defn_id'): () ));

    ## FIXME: check for uniqueness, owner selection, ..
    my $addbd = {
        owned_by => $loggedinuser,
    };
    for my $fld (@FL) {
        my $value = $query->param('ae_'.$fld) // '';
        $addbd->{$fld} = $value;
    }
    ($addbd->{type} && $addbd->{bookcode} && $addbd->{name}) || do {
        $op = 'else'; $op_error = 'add'; last;
    };

    my $result = AddInvBookDef( $addbd );
    ($result && $result ne '0E0') || do {
        $op = 'else'; $op_error = 'add'; last;
    };
    ## TODO: proper error check / success confirmation etc.
    $op_success = 'add';
    $op = 'else';
}

{
    $op eq 'delete' || last;
    my $bookdef = GetInvBookDefDetails( $bookid );
    ($bookdef && !($bookdef->{entries_total_count})) || do {
        $op = 'else'; $op_error = 'delete'; last;
    };
    my $result = DelInvBookDef( $bookid );
    ($result && $result ne "0E0") || do {
        $op = 'else'; $op_error = 'delete'; last;
    };
    $op_success = 'delete';
    $op = 'else';
}

{
    $op eq 'else' || last;

    my $abookloop = SearchInvBookDefs( { type => 'A', DETAILS => 1 } );
    for my $ab (@$abookloop) {
        my $item_count = 0;
        my $item_cost = 0;
        $ab->{entries_total_cost} = sprintf('%.02f',($ab->{entries_total_cost} || 0));
        my $acclist = SearchInvBookAccessions({ invbook_definition_id => $ab->{invbook_definition_id} });
        map {
            $item_count += $_->{entries_total_count} || 0;
            $item_cost += $_->{entries_total_cost} || 0.0;
        } @$acclist;
        $ab->{item_total_count} = $item_count;
        $ab->{item_total_cost} = sprintf('%.02f',($item_cost || 0));
    }

    my $ibookloop = SearchInvBookDefs( { type => 'I', DETAILS => 1 } );
    for my $ib (@$ibookloop) {
        $ib->{entries_total_cost} = sprintf('%.02f',($ib->{entries_total_cost} || 0));
    }

    my $wbookloop = SearchInvBookDefs( { type => 'W', DETAILS => 1 } );
    for my $wb (@$wbookloop) {
        my $item_count = 0;
        my $item_cost = 0;
        $wb->{entries_total_cost} = sprintf('%.02f',($wb->{entries_total_cost} || 0));
        my $wofflist = SearchInvBookWriteoffs({ invbook_definition_id => $wb->{invbook_definition_id} });
        map {
            $item_count += $_->{entries_unit_count} || 0;
            $item_cost += $_->{entries_total_cost} || 0.0;
        } @$wofflist;
        $wb->{item_total_count} = $item_count;
        $wb->{item_total_cost} = sprintf('%.02f',($item_cost || 0));
    }

    $template->param(
        abookloop => $abookloop,
        ibookloop => $ibookloop,
        wbookloop => $wbookloop,
        'else' => 1,
    );

    $op_success ne '' && $template->param( op_success => $op_success );
    $op_error ne '' && $template->param( op_error => $op_error );
}

output_html_with_http_headers $query, $cookie, $template->output;

sub _GetOwnerName {
    my ($borrowernumber) = shift;
    my $bh = C4::Members::GetMember( borrowernumber => $borrowernumber );
    ($bh && $bh->{surname}) || return('');
    my @BNL;
    $bh->{surname} && push(@BNL, $bh->{surname});
    $bh->{firstname} && push(@BNL, $bh->{firstname});
    join(", ", @BNL);
}

sub _GetUnassociatedBooksForType {
    my $btype = shift;
    my $curr_id = shift // 0;

    $btype eq 'I' || $btype eq 'W' || return([]);
    my $stype = ($btype eq 'I')? 'W': 'I';
    my $cbl = SearchInvBookDefs( { 'type' => $btype } );
    my $sbl = SearchInvBookDefs( { 'type' => $stype } );
    ($sbl && $cbl) || return([]);

    my $usbh = {};
    for my $bh (@$cbl) {
        $bh->{writeoff_parent_invbook_defn_id} || next;
        $usbh->{$bh->{writeoff_parent_invbook_defn_id}} = 1;
    }

    my $rh = {};
    for my $bh (@$sbl) {
        my $bkid = $bh->{invbook_definition_id};
        defined($usbh->{$bkid}) && $bkid != $curr_id && next;
        $rh->{$bkid} = {
            'ua_book_id'    => $bkid,
            'ua_book_name'  => ($bh->{name}.' ('.$bkid.')'),
            'ua_book_code'  => $bh->{bookcode}
        };
    }
    [ (map { $rh->{$_}; } (sort { $a <=> $b } keys %$rh)) ];
}
