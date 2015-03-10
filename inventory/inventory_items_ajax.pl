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

inventory_items_ajax.pl - server side script for datatables in inventory items

=head1 SYNOPSIS

This script is to be used as a data source for DataTables that load and display
the records from inventory table.

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

my @sort_column = qw/date_added inventory_number item_callnumber biblio_author
                        biblio_title biblio_publication_date accession_number acquisition_mode
                        unitprice writeoff_id notes/;
my $order_by = $sort_column[$input->param('iSortCol_0')];
my $sort_dir = ($input->param('sSortDir_0') eq 'asc') ? 'ORDER_BY' : 'ORDER_BY_DESC';
$limit = 100 if ( $limit == -1 || $limit > 100);

my $filters; my $inventory_items, my $count_records;
if (defined($input->param('filtersOn')) && $input->param('filtersOn') eq "1"){
    my @filter_param = qw/accq_from accq_to stock_from stock_to accession_no call_no/;
    my $accq_tab = "date_added";
    my $stock_tab = "inventory_number";
    my $accession_tab = "accession_number";
    my $callno_tab = "item_callnumber";
    map { $filters->{$_} = $input->param($_) if $input->param($_); } @filter_param;

    my $searchParam;
    while( my ($table, $value) = (each %$filters)){
        if ( $table =~ /^accq_(from|to)$/){
            my $search = $accq_tab . (($table =~ /from$/) ? "_ge" : "_le");
            $searchParam->{$search} = dt_from_string($value);
        } elsif ($table =~ /^stock_(from|to)$/) {
            my $search = $stock_tab . (($table =~ /from$/) ? "_ge" : "_le");
            $searchParam->{$search} = $value;
        } elsif ($table =~ /^accession_no$/){
            $searchParam->{$accession_tab} = $value;
        } elsif ($table =~ /^call_no/){
            my $search = $callno_tab;
            if ( $value =~ /^(.*)\*$/ ) {
                $search = $callno_tab . '_TR';
                $value = $1;
            }
            $searchParam->{$search} = $value;
        }
    }
    $searchParam->{'invbook_definition_id'} = $inv_book;
    $searchParam->{'LIMIT_FROM'} = $offset;
    $searchParam->{'LIMIT_AMOUNT'} = $limit;
    $searchParam->{$sort_dir} = $order_by;
    $inventory_items = SearchInvBookItems($searchParam);

    $searchParam->{'COUNT'} = 1;
    $count_records = SearchInvBookItems($searchParam);
} else {
    $inventory_items = SearchInvBookItems({
        'invbook_definition_id' => $inv_book,
        'LIMIT_FROM' => $offset,
        'LIMIT_AMOUNT' => $limit,
        $sort_dir => $order_by,
    });
    $count_records = SearchInvBookItems({
        'invbook_definition_id' => $inv_book,
        'COUNT' => 1,
    });
}

my @list = ();
foreach my $item (@$inventory_items){
    my $biblio_publisher = $item->{'biblio_publication_date'} . " / " .
                           $item->{'biblio_publication_place'};
    my $biblio_info = ({
        biblio_title => $item->{'biblio_title'},
        biblionumber => $item->{'biblionumber'},
        itemnumber   => $item->{'itemnumber'},
        });
    $biblio_info->{'biblio_title'} .= " / $item->{'publication_nr'}" if $item->{'publication_nr'};
    my $woff_item;
    if ( $item->{'writeoff_id'} ) {
        $woff_item = GetInvBookWriteoff($item->{'writeoff_id'});
    }
    my $acc_info;
    if ( $item->{'accession_id'} ) {
        $acc_info = GetInvBookAccession($item->{'accession_id'});
    }

    push @list,
        {   DT_RowId         => $item->{'invbook_item_id'},
            date_added       => $item->{'date_added'},
            inventory_number => $item->{'inventory_number'},
            item_callnumber  => $item->{'item_callnumber'},
            biblio_author    => $item->{'biblio_author'},
            biblio_title     => $biblio_info,
            biblio_publisher => $biblio_publisher,
            accession        => $acc_info,
            acquisition_mode => $item->{'acquisition_mode'},
            unitprice        => sprintf('%.02f',($item->{'unitprice'} // 0.0)),
            writeoff         => $woff_item,
            notes            => $item->{'notes'},
        };
}
my $data;
$data->{'iTotalRecords'}        = $count_records->[0]->{'ResultCount'};
$data->{'iTotalDisplayRecords'} = $count_records->[0]->{'ResultCount'};
$data->{'sEcho'}                = $input->param('sEcho') || undef;
$data->{'aaData'}               = \@list;

print to_json($data);
