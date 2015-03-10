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
use utf8;
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
my $woff_id = $input->param('woff_id');
my $offset = $input->param('iDisplayStart');
my $limit = $input->param('iDisplayLength');

my @sort_column = qw/date_added inventory_number item_callnumber biblio_author
                        biblio_title biblio_publication_date accession_number
                        unitprice writeoff_id notes/;
my $order_by = $sort_column[$input->param('iSortCol_0')];
my $sort_dir = ($input->param('sSortDir_0') eq 'asc') ? 'ORDER_BY' : 'ORDER_BY_DESC';
$limit = 100 if ( $limit == -1 || $limit > 100);

my $filters; my $inventory_items, my $count_records;
if (defined($input->param('filtersOn')) && $input->param('filtersOn') eq "1"){
    my @filter_param = qw/accq_from accq_to stock_from stock_to accession_no writeoff_id/;
    my $accq_tab = "date_added";
    my $stock_tab = "inventory_number";
    my $accession_tab = "accession_number";
    map { $filters->{$_} = $input->param($_) if $input->param($_); } @filter_param;

    my $searchParam;
    while( my ($table, $value) = (each %$filters)){
        if ( $table =~ /^accq_(from|to)$/){
            my $search = $accq_tab . (($table =~ /from$/) ? "_ge" : "_le");
            $searchParam->{$search} = dt_from_string($value);
        } elsif ($table =~ /^stock_(from|to)$/) {
            my $search = $stock_tab . (($table =~ /from$/) ? "_ge" : "_le");
            $searchParam->{$search} = $value;
        } elsif ($table =~ /^accesion_no$/){
            $searchParam->{$accession_tab} = $value;
        } elsif ($table =~ /^writeoff_id$/){
            $searchParam->{$table} = $value;
        }
    }
    $searchParam->{'invbook_definition_id'} = $inv_book;
    $searchParam->{'writeoff_id_ORNULL'} = $woff_id;
    $searchParam->{'LIMIT_FROM'} = $offset;
    $searchParam->{'LIMIT_AMOUNT'} = $limit;
    $searchParam->{$sort_dir} = $order_by;
    $inventory_items = SearchInvBookItems($searchParam);

    $searchParam->{'COUNT'} = 1;
    $count_records = SearchInvBookItems($searchParam);
} else {
    $inventory_items = SearchInvBookItems({
        'invbook_definition_id' => $inv_book,
        'writeoff_id_ORNULL' => $woff_id,
        'LIMIT_FROM' => $offset,
        'LIMIT_AMOUNT' => $limit,
        $sort_dir => $order_by,
    });
    $count_records = SearchInvBookItems({
        'invbook_definition_id' => $inv_book,
        'writeoff_id_ORNULL' => $woff_id,
        'COUNT' => 1,
    });
}

my @list = ();
foreach my $item (@$inventory_items){
    next if defined $item->{writeoff_id} && $item->{writeoff_id} != $woff_id;

    my $button;
    if (defined $item->{writeoff_id} && $item->{writeoff_id} == $woff_id ){
        $button = {
            invbook_item_id => $item->{invbook_item_id},
            op => 'delete',
        };
    } else {
        $button = {
            invbook_item_id => $item->{invbook_item_id},
            op => 'add',
        };
    }

    my $biblio = {
        biblionumber => $item->{'biblionumber'},
        biblio_title => $item->{'biblio_title'},
    };
    my $biblio_publisher = $item->{'biblio_publication_date'} . " / " .
                           $item->{'biblio_publication_place'};
    push @list,
        {   DT_RowId         => $item->{'invbook_item_id'},
            date_added       => $item->{'date_added'},
            inventory_number => $item->{'inventory_number'},
            item_callnumber  => $item->{'item_callnumber'},
            biblio_author    => $item->{'biblio_author'},
            biblio           => $biblio,
            biblio_publisher => $biblio_publisher,
            accession_id     => $item->{'accession_number'},
            unitprice        => sprintf('%.02f',($item->{'unitprice'} // 0.0)),
            notes            => $item->{'notes'},
            button           => $button,
        };
}
my $data;
$data->{'iTotalRecords'}        = $count_records->[0]->{'ResultCount'};
$data->{'iTotalDisplayRecords'} = $count_records->[0]->{'ResultCount'};
$data->{'sEcho'}                = $input->param('sEcho') || undef;
$data->{'aaData'}               = \@list;

print to_json($data);
