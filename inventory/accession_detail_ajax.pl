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
use C4::Acquisition qw/GetInvoiceDetails GetItemnumbersFromOrder/;
use C4::Items qw/GetItem/;
use C4::Biblio qw/GetBiblioFromItemNumber/;
use Koha::Misc::Files;
use C4::Members qw/GetMemberDetails/;
use Koha::Acquisition::Bookseller;

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

my $acc_id = $input->param('acc_id');

my $accession_info = GetInvBookAccession($acc_id);
my $iteminfo;

my $invbookitems = SearchInvBookItems({ accession_id => $acc_id });
foreach my $inv_item ( @{$invbookitems} ) {
    my $iteminfos = GetBiblioFromItemNumber($inv_item->{itemnumber});
    map { $iteminfos->{$_} = $inv_item->{$_} if defined $inv_item->{$_}; } keys %{$inv_item};
    push @{$accession_info->{iteminfos}}, $iteminfos;
}

if (defined $accession_info->{invoice_id} && $accession_info->{invoice_id}) {
    my $invoice_files = Koha::Misc::Files->new(
                tabletag => 'aqinvoices', recordid => $accession_info->{invoice_id} );
    $accession_info->{file_info} = $invoice_files->GetFilesInfo() if $invoice_files;
    $accession_info->{invoice_info} = GetInvoiceDetails($accession_info->{invoice_id});
    foreach my $order ( @{$accession_info->{invoice_info}->{orders}} ) {
        my @itemnumbers = GetItemnumbersFromOrder($order->{ordernumber});
        map { push @{$order->{iteminfos}}, GetItem($_); } @itemnumbers;
    }
    @{$accession_info->{invoice_info}->{orders}} = sort {
       $a->{iteminfos}->[0]->{itemnumber} <=> $b->{iteminfos}->[0]->{itemnumber}
    } @{$accession_info->{invoice_info}->{orders}};
}
$accession_info->{vendor} = Koha::Acquisition::Bookseller->fetch( { id => $accession_info->{vendor_id} } ) if
            defined $accession_info->{vendor_id};
$accession_info->{created} = GetMemberDetails($accession_info->{created_by}) if
            defined $accession_info->{created_by};
$accession_info->{modified} = GetMemberDetails($accession_info->{modified_by}) if
            defined $accession_info->{modified_by};
print to_json($accession_info, { allow_blessed => 1, convert_blessed => 1 });
