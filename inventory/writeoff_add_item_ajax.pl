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

use utf8;
use CGI;
use C4::Auth qw/check_cookie_auth/;
use C4::Context;
use C4::Output;
use C4::Inventory qw();

use Data::Dumper;

binmode STDOUT, ":encoding(utf8)";

my $input = new CGI;
my ($auth_status, $sessionID) = check_cookie_auth($input->cookie('CGISESSID'), { inventory => '*' });
unless ($auth_status eq "ok") {
    print $input->header(-type => 'text/plain', -status => '403 Forbidden');
    exit 0;
}

print $input->header( -type => 'text/plain', -charset => 'UTF-8' );

my $woff_id = $input->param('woff_id');
my $item_id = $input->param('item_id');
my $action = $input->param('action');
## my $invbook_id = $input->param('inv_book');
## my $dateadded = $input->param('dateadded');

my $add_writeoff = {
    writeoff_id => $woff_id,
    invbook_item_id => $item_id,
    action => $action,
};
my ($id, @error) = C4::Inventory::WriteoffItem($add_writeoff);

unless ($id) {
print <<HTML;
alert("Nie udało się zmodyfikować protokołu z powodu błędów: @error");
HTML
}
