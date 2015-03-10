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
use C4::Auth qw/check_cookie_auth/;
use C4::Context;
use C4::Output;
use C4::Inventory qw(ModInvBookAccession);

use Data::Dumper;
use Carp qw(croak);

binmode STDOUT, ":encoding(utf8)";

my $input = new CGI;
my ($auth_status, $sessionID) = check_cookie_auth($input->cookie('CGISESSID'), { inventory => '*' });
unless ($auth_status eq "ok") {
    print $input->header(-type => 'text/plain', -status => '403 Forbidden');
    exit 0;
}

print $input->header( -type => 'text/plain', -charset => 'UTF-8' );

my $col_no = $input->param('column') || croak("Missing 'column' parameter");
my $value = $input->param('value') // croak("Missing 'value' parameter");
my $id = $input->param('id') || croak("Missing 'id' parameter");

## my @mod_column = qw(date_accessioned accession_number invoice_document_nr none none acquisition_mode notes);
my @mod_column = qw(none none none invoice_document_nr none volumes_count fascile_count other_count special_count none acquisition_mode notes);

my $column = $mod_column[$col_no];
$column eq 'none' && croak("Column number '$col_no' editing not allowed");

my $mod_accession = {
    accession_id => $id,
    $column => $value,
};

ModInvBookAccession($mod_accession);
