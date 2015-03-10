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

accession_view.pl

=head1 SYNOPSIS
Script that handles accession details view/display

TODO: probably should be merged with accession_manage.pl (?)

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

use Date::Calc qw/Today/;

my $query = CGI->new;

my ( $template, $loggedinuser, $cookie, $userflags ) = get_template_and_user(
    {   template_name   => 'inventory/accession_view.tt',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { inventory => '*' },
    }
);

my $acc_id = $query->param('acc_id');
my $acc_info = GetInvBookAccessionDetails($acc_id);
## $data->{date_accessioned} = dt_from_string($query->param('adate'));
my $bookdef = GetInvBookDefDetails( $acc_info->{invbook_definition_id} );
my $invoice = {};
my $bookseller = {};
$invoice = GetInvoice( $acc_info->{invoice_id} ) if ($acc_info->{invoice_id});
$bookseller = Koha::Acquisition::Bookseller->fetch( { id => $acc_info->{vendor_id} } ) if ($acc_info->{vendor_id});

$acc_info->{total_cost} &&= sprintf('%.02f',$acc_info->{total_cost});
$acc_info->{entries_total_cost} = sprintf('%.02f',($acc_info->{entries_total_cost} || 0));

# function to designate unwanted fields
my @field_check=split(/\|/,$bookdef->{display_format});
foreach (@field_check) {
    next unless m/\w/o;
	$template->param( "no$_" => 1);
}

## my @booksellers = GetBookSeller();

$template->param(
    bookdef => $bookdef,
    inv_book => $bookdef->{invbook_definition_id},
    acc_info => $acc_info,
    acc_id => $acc_id,
    invoice => $invoice,
    bookseller => $bookseller,
    AcquisitionModes => GetAuthorisedValues('IVB_ACQ_MODES'),
);

output_html_with_http_headers $query, $cookie, $template->output;
