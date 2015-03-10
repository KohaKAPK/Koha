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

accession_manage.pl

=head1 SYNOPSIS
Script that handles adding, modyfing and deleting accessions from accesion book

=cut

use Modern::Perl;

use CGI;

use Koha::DateUtils;
use C4::Inventory;
use C4::Output;
use C4::Context;
use C4::Auth;
use C4::Koha;
use Koha::Acquisition::Bookseller;
use Koha::Misc::Files;

use Date::Calc qw/Today/;

my $query = CGI->new;
my ( $template, $loggedinuser, $cookie, $userflags ) = get_template_and_user(
    {   template_name   => 'inventory/accession_manage.tt',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { inventory => '*' },
        debug           => 1,
    }
);

my $op = $query->param('op');
my $inv_book = $query->param('inv_book');

my $acc_id;
unless ($op eq "add" && defined $acc_id) {
    $acc_id = $query->param('acc_id');
}

unless ( (defined $inv_book && $inv_book) || $acc_id ) {
    $template->param(
        error_inv_book => 1,
        );
    output_html_with_http_headers $query, $cookie, $template->output;
    exit 0;
}

my $modyfing = $query->param("${op}_do"); #step 2 - applying changes

if (defined $modyfing && $modyfing){
    my $data;
    $data->{invbook_definition_id} = $inv_book;
    $data->{date_accessioned} = dt_from_string($query->param('adate'));
    $data->{number_prefix} = $query->param('acc_pref');
    $data->{number_cnt} = $query->param('acc_no');
    $data->{number_suffix} = $query->param('acc_suff');
    $data->{invoice_document_nr} = $query->param('inv_no');
    $data->{total_cost} = $query->param('acost');
    $data->{volumes_count} = $query->param('avol') // 0;
    $data->{fascile_count} = $query->param('afasc') // 0;
    $data->{other_count} = $query->param('aother') // 0;
    $data->{special_count} = $query->param('aspecial_count') // 0;
    $data->{acquisition_mode} = $query->param('aacq_mode') // '';
    $data->{notes} = $query->param('anotes');
    $data->{vendor_id} = $query->param('bookseller');
    $data->{cost_managed_manually} = $query->param('cm_manually') ? 1 : 0;
    my $go_to = $query->param('go_to');

    if ( $op eq "add" ) {
        $acc_id = AddInvBookAccession($data);
    } elsif ($op eq "edit") {
        $acc_id = $query->param('acc_id');
        $data->{accession_id} = $acc_id;
        ModInvBookAccession($data);
    } elsif ($op eq "del"){

    }
    if ($op eq "add" && $go_to eq "recieve"){
        print $query->redirect("/cgi-bin/koha/acqui/parcels.pl?accession_id=$acc_id");
        exit 0;
    } elsif ($op eq "add" && $go_to eq "edit") {
        print $query->redirect("/cgi-bin/koha/inventory/accession_manage.pl?op=edit&acc_id=$acc_id");
        exit 0;
    }

}

my $prev_acc_info;
my $acc_info;
my $acc_no;
my $invoice_files;
if ($op eq "add") {
    $acc_no = GetNextAccessionNumber($inv_book);
    $prev_acc_info = GetLastAccessionInfo($inv_book);
    my ($year, $day, $month) = Today();
    $acc_info->{date_accessioned} = "$day/$month/$year";
} else {
    $acc_info = GetInvBookAccessionDetails($acc_id);
    $acc_info->{total_cost} &&= sprintf('%.02f',$acc_info->{total_cost});
    $acc_info->{entries_total_cost} = sprintf('%.02f',($acc_info->{entries_total_cost} || 0));
    $acc_no->{number} = $acc_info->{'number_cnt'};
    $acc_no->{suffix} = $acc_info->{'number_suffix'};
    $acc_no->{prefix} = $acc_info->{'number_prefix'};
    $inv_book = $acc_info->{invbook_definition_id} unless $inv_book;

    if ( C4::Context->preference('AcqEnableFiles') && defined $acc_info->{invoice_id} ) {
        $invoice_files = Koha::Misc::Files->new(
                tabletag => 'aqinvoices', recordid => $acc_info->{invoice_id} );
    }
}

# function to designate unwanted fields
my $check_UnwantedField= GetInvBookDef($inv_book)->{display_format};
my $default_soa = GetInvBookDef($inv_book)->{default_location};

my @field_check=split(/\|/,$check_UnwantedField);
foreach (@field_check) {
    next unless m/\w/o;
	$template->param( "no$_" => 1);
}
defined( $invoice_files ) && $template->param( files => $invoice_files->GetFilesInfo() );

my @booksellers = Koha::Acquisition::Bookseller->search;

$template->param(
        op => $op,
        inv_book => $inv_book,
        acc_pref => $acc_no->{prefix},
        acc_no => $acc_no->{number},
        acc_suff => $acc_no->{suffix},
        acc_info => $acc_info,
        acc_id => $acc_id,
        AcquisitionModes => GetAuthorisedValues('IVB_ACQ_MODES'),
        prev_acc_info => $prev_acc_info,
        default_soa => $default_soa,
        booksellers => \@booksellers,
);


output_html_with_http_headers $query, $cookie, $template->output;
