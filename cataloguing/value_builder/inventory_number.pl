#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;
no warnings 'redefine';
use C4::Context;
use C4::Inventory qw/GetNextInventoryNumber GetActiveInvBooks/;
use C4::Output;
use C4::Auth;

use utf8;
=head1 plugin_parameters

other parameters added when the plugin is called by the dopop function

=cut

sub plugin_parameters {
#   my ($dbh,$record,$tagslib,$i,$tabloop) = @_;
    return "";
}

=head1 plugin_javascript

The javascript function called when the user enters the subfield.
contain 3 javascript functions :
* one called when the field is entered (OnFocus). Named FocusXXX
* one called when the field is leaved (onBlur). Named BlurXXX
* one called when the ... link is clicked (<a href="javascript:function">) named ClicXXX

returns :
* XXX
* a variable containing the 3 scripts.
the 3 scripts are inserted after the <input> in the html code

=cut

sub plugin_javascript {
	my ($dbh,$record,$tagslib,$field_number,$tabloop) = @_;
	my $function_name= "inventory".(int(rand(100000))+1);

    my $inv_books = GetActiveInvBooks('I');

    my $invbooks_options; my $invbooks_suffix;
    foreach (@$inv_books){
    $invbooks_options .= <<END_OPT;
        <option value="$_->{invbook_definition_id}">$_->{name}</option>
END_OPT
    $invbooks_suffix .= <<END_SUFF;
        "$_->{number_suffix}": '$_->{invbook_definition_id}',
END_SUFF
    }

    my $js  = <<END_OF_JS;
<select id="select_$function_name" name="inv_book">
<option value="" disabled selected style="display:none">Wybierz Księgę inwentarzową.</option>
$invbooks_options
</select>
<input type="checkbox" name="addto_inv" value="1" id="add_to$function_name">Dodać do inwentarza?</input>
<script type="text/javascript">
//<![CDATA[

function Blur$function_name(index) {
    //barcode validation might go here
}

function Focus$function_name(subfield_managed, id, force) {
    return 0;
}

function Clic$function_name(id) {
    return Focus$function_name('not_relavent', id, 1);
}

\$('#select_$function_name').on('change', function() {
    if ( (\$('#add_to$function_name').is(':checked') == true ) &&
         (window.first_val$field_number.length == 0) ) {

        var url = '../cataloguing/plugin_launcher.pl?plugin_name=inventory_number.pl&inv_book=' + this.value;
        var req = \$.get(url);
        req.done(function(resp){
            document.getElementById('$field_number').value = resp;
            return 1;
        });
    }
});

\$('#add_to$function_name').change(function(){
    if (\$('#add_to$function_name').is(':checked') == false){
        \$('#$field_number').prop('readonly', true);
        \$('#select_$function_name').prop('disabled', true);
        \$('#$field_number').val(window.first_val$field_number);
    } else {
        \$('#$field_number').prop('readonly', false);
        \$('#select_$function_name').prop('disabled', false);
    }
});

\$(document).ready(function(){
        window.first_val$field_number = \$('#$field_number').val();
        if ( window.first_val$field_number.length != 0 ) {
            var suffixes = { $invbooks_suffix };
            var regexp = /\\d*(-\\w*)/;
            var suffix = regexp.exec(window.first_val$field_number);
            var book_id = suffixes[suffix[1]];
            \$('#select_$function_name').val(book_id) ;
        }
        \$('#$field_number').prop('readonly', true);
        \$('#select_$function_name').prop('disabled', true);
});
//]]>
</script>
END_OF_JS

    return ($function_name, $js);
}

=head1

plugin: useless here

=cut

sub plugin {
    my ($input) = @_;
    my $inv_book = $input->param('inv_book');

    my ($template, $loggedinuser, $cookie) = get_template_and_user({
        template_name   => "cataloguing/value_builder/ajax.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => {editcatalogue => '*'},
        debug           => 1,
    });

    my ( $next_number, undef, $suffix ) = GetNextInventoryNumber($inv_book);

    my $number = "@$next_number$suffix";
    $template->param(
            return=>($number),
            );

    output_html_with_http_headers $input, $cookie, $template->output;
}

1;
