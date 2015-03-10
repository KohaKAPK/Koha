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
use C4::Auth qw(check_cookie_auth);
use C4::Inventory qw(ModInvBookWriteoff);

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

## my @mod_column = qw(details_control date_writeoff writeoff_number base_document_number base_seq_nr_first_last entries_unit_count total_cost reason notes);
my @mod_column = qw(none none none none none none none none notes);

my $column = $mod_column[$col_no];
$column eq 'none' && croak("Column number '$col_no' editing not allowed");

my $mod_writeoff = {
    writeoff_id => $id,
    $column => $value,
};

ModInvBookWriteoff($mod_writeoff);
