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

item_view.pl

=head1 SYNOPSIS
Script that handles inventory item details view/display

=cut

use Modern::Perl;

use CGI;

use Koha::DateUtils;
use C4::Inventory;
use C4::Output;
use C4::Context;
use C4::Auth;
use C4::Koha;
use C4::Acquisition qw/GetInvoice/;
use Koha::Acquisition::Bookseller;

my $query = CGI->new;

my ( $template, $loggedinuser, $cookie, $userflags ) = get_template_and_user(
    {   template_name   => 'inventory/item_view.tt',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { inventory => '*' },
    }
);

my $item_id = $query->param('item_id');
my $item = GetInvBookItemDetails($item_id);
my $bookdef = GetInvBookDefDetails( $item->{invbook_definition_id} );

my $acc_info = {};
$acc_info = GetInvBookAccessionDetails( $item->{accession_id} ) if ($item->{accession_id});

my $invoice = {};
$invoice = GetInvoice( $acc_info->{invoice_id} ) if ($acc_info->{invoice_id});

my $bookseller = {};
$bookseller = Koha::Acquisition::Bookseller->search if ($acc_info->{vendor_id});

$item->{unitprice} = sprintf('%.02f',($item->{unitprice} || 0));

# function to designate unwanted fields
my @field_check=split(/\|/,$bookdef->{display_format});
foreach (@field_check) {
    next unless m/\w/o;
	$template->param( "no$_" => 1);
}

$template->param(
    bookdef => $bookdef,
    inv_book => $bookdef->{invbook_definition_id},
    item => $item,
    item_id => $item_id,
    acc_info => $acc_info,
    invoice => $invoice,
    bookseller => $bookseller,
    AcquisitionModes => GetAuthorisedValues('IVB_ACQ_MODES'),
);

output_html_with_http_headers $query, $cookie, $template->output;
