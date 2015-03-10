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

writeoff_detail_ajax.pl - server side script for datatables writeoff
details handling

=head1 SYNOPSIS

This script is used as a data source for DataTables that load and display
the details of records from invbook_writeoffs table.

=cut

use Modern::Perl;

use CGI qw ( -utf8 );
use JSON qw/ to_json /;

use Carp qw/croak/;
use C4::Context;
use C4::Auth qw/check_api_auth/;
use C4::Inventory;
use C4::Members qw/GetMemberDetails/;

use Koha::DateUtils;
use Data::Dumper;

binmode STDOUT, ":encoding(utf8)";

my $input = new CGI;

my ($status, $cookie, $sessionID) = check_api_auth($input, { inventory => '*'} );
unless ($status eq "ok") {
    print $input->header(-type => 'text/plain', -status => '403 Forbidden');
    exit 0;
}

print $input->header( -type => 'text/plain', -charset => 'UTF-8' );

my $woff_id = $input->param('woff_id');
croak "No write off id" unless ( defined $woff_id && $woff_id );

my $writeoff_info = GetInvBookWriteoffDetails($woff_id);
croak "Write off with $woff_id not found" unless $writeoff_info;
my $writeoff_items = SearchInvBookWfBaseItems({ writeoff_id => $woff_id });
croak "Fetching entries list for writeoff $woff_id failed" unless defined $writeoff_items;

my $created = GetMemberDetails($writeoff_info->{created_by}) if 
        defined $writeoff_info->{created_by};
$writeoff_info->{created} = "$created->{firstname} $created->{surname}" if defined $created;
my $modified = GetMemberDetails($writeoff_info->{modified_by}) if 
        defined $writeoff_info->{modified_by};
$writeoff_info->{modified} = "$modified->{firstname} $modified->{surname}" if defined $modified;

foreach ( @$writeoff_items ) {
    next unless $_->{invbook_item_id};
    #only 1 element will be returned to we may shift it, to get rid of unnecessary arrayref
    $_->{inv_item} = shift SearchInvBookItems({ invbook_item_id => $_->{invbook_item_id} });

    push @{$writeoff_info->{items}}, $_;
}

$writeoff_info->{items} ||= [];

print to_json($writeoff_info, { allow_blessed => 1, convert_blessed => 1 });
