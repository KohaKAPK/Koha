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

inventory_writeoffs_ajax.pl - server side script for datatables inventory
writeoff books handling

=head1 SYNOPSIS

This script is used as a data source for DataTables that load and display
the records from invbook_writeoffs table.

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

my @sort_column = qw/none date_writeoff writeoff_number
    base_document_number none none none reason none/;

my $order_by = $sort_column[$input->param('iSortCol_0')];
my $sort_dir = ($input->param('sSortDir_0') eq 'asc') ? 'ORDER_BY' : 'ORDER_BY_DESC';
$limit = 100 if ( $limit == -1 || $limit > 100);

my $filters; my $result_items; my $count_records;
if (defined($input->param('filtersOn')) && $input->param('filtersOn') eq "1"){
    my @filter_param = qw/wfdate_from wfdate_to wf_number wf_base_document_number wf_reason/;
    map { $filters->{$_} = $input->param($_) if $input->param($_); } @filter_param;

    my $searchParam;
    while (my ($table, $value) = (each %$filters)) {
        if ( $table =~ /^wfdate_(from|to)$/) {
            my $search = "date_writeoff" . (($table =~ /from$/) ? "_ge" : "_le");
            $searchParam->{$search} = dt_from_string($value);
        } elsif ($table eq 'wf_number') {
            $searchParam->{writeoff_number} = $value;
        } elsif ($table eq 'wf_base_document_number') {
            $searchParam->{base_document_number} = $value;
        } elsif ($table eq 'wf_reason') {
            $searchParam->{reason} = $value;
        }
    }
    $searchParam->{'invbook_definition_id'} = $inv_book;
    $searchParam->{'LIMIT_FROM'} = $offset;
    $searchParam->{'LIMIT_AMOUNT'} = $limit;
    $searchParam->{$sort_dir} = $order_by;
    $result_items = SearchInvBookWriteoffs($searchParam);

    $searchParam->{'COUNT'} = 1;
    $count_records = SearchInvBookWriteoffs($searchParam);
} else {
    $result_items = SearchInvBookWriteoffs({
        'invbook_definition_id' => $inv_book,
        'LIMIT_FROM' => $offset,
        'LIMIT_AMOUNT' => $limit,
        $sort_dir => $order_by,
    });
    $count_records = SearchInvBookWriteoffs({
        'invbook_definition_id' => $inv_book,
        'COUNT' => 1,
    });
}

my @list = ();
foreach my $item (@$result_items) {
    my $entries_total_cost = $item->{entries_total_cost};
    $entries_total_cost = sprintf('%.02f',($entries_total_cost // 0.0));
    my $entries_unit_count = ($item->{count_managed_manually}) ?
        $item->{unit_count}: $item->{entries_unit_count};

    push @list,
        {   DT_RowId                => $item->{writeoff_id},
            details_control         => '',
            date_writeoff           => $item->{date_writeoff},
            writeoff_number         => $item->{writeoff_number},
            base_document_number    => $item->{base_document_number},
            base_seq_nr_first_last  => $item->{base_seq_nr_first_last}, ## FIXME
            entries_unit_count      => $entries_unit_count,
            entries_total_cost      => $entries_total_cost,
            total_cost              => $item->{total_cost},
            reason                  => $item->{reason},
            notes                   => $item->{notes},
            cost_manually           => $item->{cost_managed_manually},
        };
}

my $data;
$data->{'iTotalRecords'}        = $count_records->[0]->{'ResultCount'};
$data->{'iTotalDisplayRecords'} = $count_records->[0]->{'ResultCount'};
$data->{'sEcho'}                = $input->param('sEcho') || undef;
$data->{'aaData'}               = \@list;

print to_json($data);
