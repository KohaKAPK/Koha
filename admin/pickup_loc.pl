#!/usr/bin/perl

# Copyright (C) 2014-2015 by Jacek Ablewicz
# Copyright (C) 2014-2015 by Rafal Kopaczka
# Copyright (C) 2014-2015 by Krakowska Akademia im. Andrzeja Frycza Modrzewskiego
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use CGI;
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Members qw/GetBorrowercategoryList/;
use C4::Koha;
use C4::ItemType;
use C4::Circulation;
use C4::Branch qw/GetBranchesLoop/;

use Data::Dumper;

my $input = new CGI;
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "admin/pickup_location.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { parameters => 'parameters_remaining_permissions'},
        debug           => 1,
    }
);

if( $input->param('action') eq 'add'  ){
    AddPickupRule($input->param('type'), $input->param('value'), $input->param('location'));
}
if ( $input->param('action') eq 'del' ){
    DelPickupRule($input->param('pickuprule_id'));
}

my $borrower_categories = GetBorrowercategoryList();
my $pickup_locations = GetAuthorisedValues('PICKUP');
my $restricted_items = GetAuthorisedValues('RESTRICTED');

my $branches = GetBranchesLoop();
my @item_types = C4::ItemType->all;

my @rule_types = (
                    {
                      type   => "BC",
                      name   => "Borrower category",
                      values => $borrower_categories,
                    },
                    {
                      type   => "IT",
                      name   => "Item type",
                      values => \@item_types,
                    },
                    {
                      type   => "BR",
                      name   => "Branch",
                      values => $branches,
                    },
                    {
                      type   => "RA",
                      name   => "Restricted items",
                      values => $restricted_items,
                    },
                 );

my $defined_rules = GetAllPickupRules();

$template->param(
                    rule_types       => \@rule_types,
                    defined_rules    => $defined_rules,
                    pickup_locations => $pickup_locations,
                );

output_html_with_http_headers $input, $cookie, $template->output;
