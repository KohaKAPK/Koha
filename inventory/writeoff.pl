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
use C4::Koha;

my $query = CGI->new;
my ( $template, $loggedinuser, $cookie, $userflags ) = get_template_and_user(
    {   template_name   => 'inventory/writeoff.tt',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { inventory => '*' },
        debug           => 1,
    }
);

my $inv_book = $query->param('inv_book');
my $inv_books = GetInvBooks('W');

$template->param( inv_book => $inv_book,
                  inv_books => $inv_books,
                  WriteoffReasons => GetAuthorisedValues('IVB_WOFF_REASONS'),
);

unless ($inv_book) {
    $template->param(
        error_inv_book => 1,
        );
    output_html_with_http_headers $query, $cookie, $template->output;
    exit 0;
}

# function to designate unwanted fields
my $check_UnwantedField = GetInvBookDef($inv_book)->{display_format};
my @field_check = split(/\|/,$check_UnwantedField);
foreach (@field_check) {
    next unless m/\w/o;
	$template->param( "no$_" => 1);
}
my $filtersOn = $query->param('filtersOn') || 0;
if ( $filtersOn == 1 ){
    my @filter_param = qw/wfdate_from wfdate_to wf_number wf_base_document_number wf_reason/;
    my $filters;
    map { $filters->{$_} = $query->param($_) if $query->param($_); } @filter_param;

    $template->param(
        filtersOn => 1,
        filters => $filters,
    );
}

output_html_with_http_headers $query, $cookie, $template->output;
