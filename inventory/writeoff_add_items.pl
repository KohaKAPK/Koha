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

use Modern::Perl;

use CGI;
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Inventory;


my $query = CGI->new;
my ( $template, $loggedinuser, $cookie, $userflags ) = get_template_and_user(
    {   template_name   => 'inventory/writeoff_add_items.tt',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { inventory => '*' },
        debug           => 1,
    }
);

my $inv_book = $query->param('inv_book');
my $woff_id = $query->param('woff_id');
my $inv_books = GetInvBooks('I');

my $woff_info = SearchInvBookWriteoffs({ 'writeoff_id' => $woff_id });
my $closed = ( $woff_info->[0]->{current_status} eq "CL" ||
               $woff_info->[0]->{current_status} eq "PR" ) ? 1 : 0;

$template->param( inv_book => $inv_book,
                  inv_books => $inv_books,
                  woff_invbook_id => $woff_info->[0]->{invbook_definition_id},
                  woff_id => $woff_id,
                  dateadded => $woff_info->[0]->{date_writeoff},
                  woff_info => $woff_info,
                  closed => $closed,
);

unless ($inv_book) {
    $template->param(
        error_inv_book => 1,
        );
    output_html_with_http_headers $query, $cookie, $template->output;
    exit 0;
}

my $filtersOn = $query->param('filtersOn') || 0;
if ( $filtersOn == 1 ){
    my @filter_param = qw/accq_from accq_to stock_from stock_to accession_no/;
    my $filters;
    map { $filters->{$_} = $query->param($_) if $query->param($_); } @filter_param;

    $template->param(
        filtersOn => 1,
        filters => $filters,
    );
}

output_html_with_http_headers $query, $cookie, $template->output;
