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

inventory_accessions_ajax.pl - server side script for datatables inventory
accession books handling

=head1 SYNOPSIS

This script is used as a data source for DataTables that load and display
the records from invbook_accessions table.

=cut

use Modern::Perl;

use CGI;
use JSON qw/ to_json /;

use C4::Context;
use C4::Charset;
use C4::Auth qw/check_cookie_auth/;
use C4::Inventory;

use Koha::DateUtils;
use Data::Dumper;

binmode STDOUT, ":encoding(utf8)";

my $input = new CGI;
my ($auth_status, $sessionID) = check_cookie_auth($input->cookie('CGISESSID'), { inventory => '*' });
unless ($auth_status eq "ok") {
    print $input->header(-type => 'text/plain', -status => '403 Forbidden');
    exit 0;
}

print $input->header( -type => 'text/plain', -charset => 'UTF-8' );

my $inv_book = $input->param('inv_book');
my $offset = $input->param('iDisplayStart');
my $limit = $input->param('iDisplayLength');

my @sort_column = qw/
    none date_accessioned accession_number invoice_document_nr none volumes_count
    fascile_count other_count special_count none acquisition_mode notes/;
my $order_by = $sort_column[$input->param('iSortCol_0')];
my $sort_dir = ($input->param('sSortDir_0') eq 'asc') ? 'ORDER_BY' : 'ORDER_BY_DESC';
$limit = 100 if ( $limit == -1 || $limit > 100);

my $filters; my $inventory_items, my $count_records;
if (defined($input->param('filtersOn')) && $input->param('filtersOn') eq "1"){
    my @filter_param = qw/accdate_from accdate_to accession_no invoice_no acc_acq_mode/;
    map { $filters->{$_} = $input->param($_) if $input->param($_); } @filter_param;

    my $searchParam;
    while( my ($table, $value) = (each %$filters)){
        if ( $table =~ /^accdate_(from|to)$/){
            my $search = "date_accessioned" . (($table =~ /from$/) ? "_ge" : "_le");
            $searchParam->{$search} = dt_from_string($value);
        } elsif ($table eq 'invoice_no') {
            $searchParam->{invoice_document_nr} = $value;
        } elsif ($table eq 'accession_no'){
            $searchParam->{accession_number} = $value;
        } elsif ($table eq 'acc_acq_mode'){
            $searchParam->{acquisition_mode} = $value;
        }
    }
    $searchParam->{'invbook_definition_id'} = $inv_book;
    $searchParam->{'LIMIT_FROM'} = $offset;
    $searchParam->{'LIMIT_AMOUNT'} = $limit;
    $searchParam->{$sort_dir} = $order_by;
    $inventory_items = SearchInvBookAccessions($searchParam);

    $searchParam->{'COUNT'} = 1;
    $count_records = SearchInvBookAccessions($searchParam);
} else {
    $inventory_items = SearchInvBookAccessions({
        'invbook_definition_id' => $inv_book,
        'LIMIT_FROM' => $offset,
        'LIMIT_AMOUNT' => $limit,
        $sort_dir => $order_by,
    });
    $count_records = SearchInvBookAccessions({
        'invbook_definition_id' => $inv_book,
        'COUNT' => 1,
    });
}

my @list = ();
foreach my $item (@$inventory_items){

    push @list,
        {   DT_RowId                => $item->{accession_id},
            details_control        => '',
            date_accessioned        => $item->{date_accessioned},
            accession_number        => $item->{accession_number},
            invoice_document_nr     => $item->{invoice_document_nr},
            entries_total_cost      => $item->{entries_total_cost},
            total_cost              => $item->{total_cost},
            cost_manually           => $item->{cost_managed_manually},
            entries_total_count     => $item->{entries_total_count},
            entries_volumes_count     => $item->{volumes_count},
            entries_fascile_count     => $item->{fascile_count},
            entries_other_count     => $item->{other_count},
            entries_special_count     => $item->{special_count},
            acquisition_mode 		=> $item->{acquisition_mode},
            notes            		=> $item->{notes},
        };
}
my $data;
$data->{'iTotalRecords'}        = $count_records->[0]->{'ResultCount'};
$data->{'iTotalDisplayRecords'} = $count_records->[0]->{'ResultCount'};
$data->{'sEcho'}                = $input->param('sEcho') || undef;
$data->{'aaData'}               = \@list;

print to_json($data);
