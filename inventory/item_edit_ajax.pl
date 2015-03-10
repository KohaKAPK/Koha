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
use C4::Inventory;
use C4::Items qw/ModItem/;

use Data::Dumper;

binmode STDOUT, ":encoding(utf8)";

my $input = new CGI;
my ($auth_status, $sessionID) = check_cookie_auth($input->cookie('CGISESSID'), { inventory => '*' });
unless ($auth_status eq "ok") {
    print $input->header(-type => 'text/plain', -status => '403 Forbidden');
    exit 0;
}

print $input->header( -type => 'text/plain', -charset => 'UTF-8' );

my $col_no = $input->param('column') || die() ;
my $value = $input->param('value') || '';
my $id = $input->param('id') || die();

my @mod_column = qw/date_added inventory_number callnumber biblio_author
                        biblio_title biblio_publication_date accession_number acqisition_mode
                        unitprice writeoff_id notes/;
my $table = $mod_column[$col_no];

my $mod_item = { invbook_item_id => $id,
              $table => $value,
            };
#TODO: Add modification log

ModInvBookItem($mod_item);

my $inv_item = GetInvBookItemByID($id);
my $itemnumber = $inv_item->{itemnumber};
my %item_mod_column = (
        callnumber  => 'itemcallnumber',
        unitprice => 'price',
        );

{
    last unless (defined($itemnumber) && exists($item_mod_column{$table}));
    ModItem({ $item_mod_column{$table} => $value }, undef, $itemnumber);
}
