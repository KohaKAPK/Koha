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

writeoff_manage.pl

=head1 SYNOPSIS
Script that handles adding, modyfing and deleting writeoffs.

=cut

use Modern::Perl;

use CGI;

use Koha::DateUtils;
use C4::Inventory;
use C4::Output;
use C4::Context;
use C4::Auth;
use C4::Koha;

use Date::Calc qw/Today/;

my $query = CGI->new;
my ( $template, $loggedinuser, $cookie, $userflags ) = get_template_and_user(
    {   template_name   => 'inventory/writeoff_manage.tt',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { inventory => '*' },
        debug           => 1,
    }
);

my $op = $query->param('op');
my $inv_book = $query->param('inv_book');

my $woff_id;
unless ($op eq "add" && defined $woff_id) {
    $woff_id = $query->param('woff_id');
}

unless ( (defined $inv_book && $inv_book) || $woff_id ) {
    $template->param(
        error_inv_book => 1,
        );
    output_html_with_http_headers $query, $cookie, $template->output;
    exit 0;
}

my $modyfing = $query->param("${op}_do"); #step 2 - applying changes
my $closing = $query->param("current_status");
if (defined $closing && $closing eq "CL") {
    $op = "close";
    CloseWriteOffBasis($woff_id);
}

if (defined $modyfing && $modyfing){
    my $data;
    $data->{invbook_definition_id} = $inv_book;
    $data->{date_writeoff} = dt_from_string($query->param('wdate'));
    $data->{writeoff_number} = $query->param('woff_no');
    $data->{base_document_number_prefix} = $query->param('base_prefix');
    $data->{base_document_number_cnt} = $query->param('base_cnt');
    $data->{base_document_number_suffix} = $query->param('base_suffix');
    $data->{total_cost} = $query->param('wcost') // 0; #editable??
    $data->{unit_count} = $query->param('wcount') // 0;#editable??
    $data->{reason} = $query->param('woff_reason') // '';
    $data->{notes} = $query->param('wnotes');
    $data->{base_document_description} = $query->param('woff_desc');
    $data->{cost_managed_manually} = $query->param('cm_manually') ? 1 : 0;
    $data->{count_managed_manually} = $query->param('uc_manually') ? 1 : 0;
    my $go_to = $query->param('go_to');
    my $user = C4::Context->userenv;

    if ( $op eq "add" ) {
        $data->{created_by} = $user->{number};
        $woff_id = AddInvBookWriteoff($data);
    } elsif ($op eq "edit") {
        ## warn Data::Dumper::Dumper $user;
        $woff_id = $query->param('woff_id');
        $data->{modified_by} = $user->{number};
        $data->{writeoff_id} = $woff_id;
        ModInvBookWriteoff($data);
    } elsif ($op eq "del"){
        #TODO: Add delete
    }
    my $book = GetInvBookDef($inv_book);
    my $parent_invbook = $book->{writeoff_parent_invbook_defn_id};
    if ($op eq "add" || $op eq "edit"){
        my $redirect_to=($data->{count_managed_manually})?
            "writeoff_manage.pl?op=edit&woff_id=$woff_id&inv_book=$inv_book":
            "writeoff_add_items.pl?woff_id=$woff_id&inv_book=$parent_invbook&woff_inv_book=$inv_book";
        print $query->redirect("/cgi-bin/koha/inventory/".$redirect_to);
        exit 0;
    }

}

my $woff_info;
my $woff_no;
my $parent_invbook;
if ($op eq "add") {
    $woff_no = GetNextWriteoffNumbers($inv_book);
    my ($year, $day, $month) = Today();
    $woff_info->{date_writeoff} = "$day/$month/$year";
} else {
    $woff_info = GetInvBookWriteoffDetails($woff_id);
    $woff_info->{total_cost} &&= sprintf('%.02f',$woff_info->{total_cost});
    $woff_info->{entries_total_cost} = sprintf('%.02f',($woff_info->{entries_total_cost} || 0));
    $woff_no->{number} = $woff_info->{'writeoff_number'};
    $woff_no->{base_prefix} = $woff_info->{'base_document_number_prefix'};
    $woff_no->{base_cnt} = $woff_info->{'base_document_number_cnt'};
    $woff_no->{base_suffix} = $woff_info->{'base_document_number_suffix'};

    $inv_book = $woff_info->{invbook_definition_id} unless $inv_book;
    my $book = GetInvBookDef($inv_book);
    $parent_invbook = $book->{writeoff_parent_invbook_defn_id};
}

# function to designate unwanted fields
my $check_UnwantedField= GetInvBookDef($inv_book)->{display_format};
my @field_check=split(/\|/,$check_UnwantedField);
foreach (@field_check) {
    next unless m/\w/o;
	$template->param( "no$_" => 1);
}

$template->param(
        op => $op,
        inv_book => $inv_book,
        parent_invbook => $parent_invbook,
        woff_no => $woff_no->{number},
        base_prefix => $woff_no->{base_prefix},
        base_cnt => $woff_no->{base_cnt},
        base_suffix => $woff_no->{base_suffix},
        woff_info => $woff_info,
        woff_id => $woff_id,
        WriteoffReasons => GetAuthorisedValues('IVB_WOFF_REASONS'),
);


output_html_with_http_headers $query, $cookie, $template->output;
