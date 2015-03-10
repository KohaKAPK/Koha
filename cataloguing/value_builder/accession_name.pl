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
use C4::Inventory;
use utf8;
=head1

plugin_parameters : useless here

=cut

sub plugin_parameters {
	# my ($dbh,$record,$tagslib,$i,$tabloop) = @_;
	return "";
}

=head1

plugin_javascript : the javascript function called when the user enters the subfield.
contain 3 javascript functions :
* one called when the   field  is entered (OnFocus) named FocusXXX
* one called when the   field  is  left   (onBlur ) named BlurXXX
* one called when the ... link is clicked (onClick) named ClicXXX

returns :
* XXX
* a variable containing the 3 scripts.
the 3 scripts are inserted after the <input> in the html code

=cut

sub plugin_javascript {
	my ($dbh,$record,$tagslib,$field_number,$tabloop) = @_;
	my $function_name = "accession_name".(int(rand(100000))+1);
my $acc_info = C4::Inventory::GetInvBookAccession($record->{accession_id});

my $res;
my $focus =''; my $click =''; my $after ='', my $before ='';

if ( defined $acc_info ) {
    $focus = <<END_JS;
    if (\$('#' + id).val() == '' || force) {
        \$('#' + id).val('$acc_info->{accession_number}');
    }
END_JS
    $click = <<END_JS;
    if (\$('#' + id).val() == '' || force) {
    \$('#' + id).val('$acc_info->{accession_number}');
    }
END_JS
    $after = <<END_JS;
    \$(document).ready(function(){
            \$('#$field_number').val("$acc_info->{accession_number}");
    });
END_JS
} else {
    $before = <<END_JS;
    <input type="checkbox" name="mod_acc" value="1" id="mod_acc$function_name">Zmień/dodaj do akcesji</input>
END_JS
    $after = <<END_JS;
    \$('#mod_acc$function_name').change(function(){
        if (\$('#mod_acc$function_name').is(':checked') == false){
            \$('#$field_number').prop('readonly', true);
            \$('#$field_number').val(window.first_val$field_number);
        } else {
            \$('#$field_number').prop('readonly', false);
        }
    });

    \$(document).ready(function(){
            window.first_val$field_number = \$('#$field_number').val();
            \$('#$field_number').prop('readonly', true);
    });
END_JS
}
	$res  = <<END_OF_JS;
    $before
    <script type="text/javascript">
    //<![CDATA[

    function Blur$function_name(index) {
        //date validation could go here
    }

    function Focus$function_name(subfield_managed, id, force) {
        $focus
       return 0;
    }

    function Clic$function_name(id) {
        $click
        return 0;
    }
    $after
    //]]>
    </script>
END_OF_JS

	return ($function_name, $res);
}

=head1

plugin: useless here.

=cut

sub plugin {
#    my ($input) = @_;
    return "";
}

1;
