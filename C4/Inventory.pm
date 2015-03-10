package C4::Inventory;

# Copyright (C) 2014-2015 by Jacek Ablewicz
# Copyright (C) 2014-2015 by Rafal Kopaczka
# Copyright (C) 2014-2015 by Krakowska Akademia im. Andrzeja Frycza Modrzewskiego
#
# This file is part of Koha.
#
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

use C4::Context;
use C4::Items qw/GetItem ModItem/;
use C4::Biblio qw /GetBiblioData/;
use C4::Acquisition qw/GetOrderFromItemnumber GetInvoice/;
use Date::Calc qw/Today/;

use vars qw{$VERSION @ISA @EXPORT};

BEGIN {
    $VERSION = "master??";
    require Exporter;
    @ISA = qw/Exporter/;
    @EXPORT = qw/
        &GetInvBooks
        &GetActiveInvBooks
        &GetBookTypes

        &AddInvBookDef
        &ModInvBookDef
        &GetInvBookDef
        &GetInvBookDefDetails
        &SearchInvBookDefs
        &DelInvBookDef

        &AddInvBookItem
        &AddItemToInventory
        &AddItemToInventory_BPK_Book
        &ModInvBookItem
        &RefreshItemInInventory
        &GetInvBookItemByID
        &GetInvBookItemByNumber
        &GetInvBookItemDetails
        &GetInvBookItemInfoByItemNr
        &SearchInvBookItems
        &DelInvBookItem

        &AddInvBookAccession
        &GetInvBookAccession
        &GetInvBookAccessionDetails
        &ModInvBookAccession
        &SearchInvBookAccessions
        &DelInvBookAccession

        &GetLastAccessionInfo
        &GetNextAccessionNumber
        &GetNextInventoryNumber
        &GetNextWriteoffNumbers

        &AddInvBookWriteoff
        &GetInvBookWriteoff
        &GetInvBookWriteoffDetails
        &ModInvBookWriteoff
        &SearchInvBookWriteoffs
        &DelInvBookWriteoff

        &AddInvBookWfBaseItem
        &GetInvBookWfBaseItem
        &GetInvBookWfBaseItemDetails
        &ModInvBookWfBaseItem
        &SearchInvBookWfBaseItems
        &DelInvBookWfBaseItem
        &CloseWriteOffBasis
    /;
}

=head1 NAME

C4::Inventory - Functions to deal with inventory module in Koha

=head1 SYNOPIS

use C4::Inventory;

=head1 DESCRIPTION

TODO: Add description.

=head1 FUNCTIONS

=head2 GetInvBooks

Returns all inventory | accession | writeoff books defined
in invbook_definitions table.

=cut

sub GetInvBooks {
    my ( $bookType ) = @_;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT * FROM invbook_definitions";
    $query .= " WHERE type LIKE ?" if (defined($bookType) && $bookType ne '');

    my $sth = $dbh->prepare($query);
    (defined($bookType) && $bookType ne '') ? $sth->execute($bookType) : $sth->execute();

    return $sth->fetchall_arrayref({});
}

sub GetActiveInvBooks {
    my ( $bookType ) = @_;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT * FROM invbook_definitions";
    $query .= " WHERE type LIKE ? AND active = 1" if (defined($bookType) && $bookType ne '');

    my $sth = $dbh->prepare($query);
    (defined($bookType) && $bookType ne '') ? $sth->execute($bookType) : $sth->execute();

    return $sth->fetchall_arrayref({});
}
sub GetBookTypes {

    my $dbh = C4::Context->dbh;
    my $query = "SELECT type FROM invbook_definitions GROUP BY type";
    my $sth = $dbh->prepare($query);
    $sth->execute();

    return $sth->fetchall_arrayref({});
}


=head2 AddInvBookDef

    $recid = AddInvBookDef($ivbdef);

Creates a new inventory book definition record; $ivbdef is a hashref
whose keys are the fields of the invbook_definitions table. Some
parameters (bookcode, type) have to be present.

Allowed (supported) inventory book types:

   'I': Inventory (item) book
   'A': Accession book
   'W': Writeoff book

This function returns the unique ID (invbook_definition_id) of the newly
created inventory book definition record or undef in case of an error.

=cut

sub AddInvBookDef {
    my ($data) = @_;

    my $dbh = C4::Context->dbh;
    my @fldlst_req = qw(
        bookcode type
    );
    my @fldlst_opt = qw(
        invbook_definition_id name name_abbrev branchcode
        owned_by active print_format display_format
        numbering_format date_start_of_numbering notes
        page_number_last entry_number_last total_items total_cost
        cn_prefix cn_suffix default_location
        writeoff_basis_seq_number_last writeoff_parent_invbook_defn_id
        number_prefix number_suffix
    );

    my @qparts; my @qparams; my $fld;
    for $fld (@fldlst_req) {
        (defined($data->{$fld}) && $data->{$fld} ne '') || return();
        $fld eq 'type' && ($data->{$fld} =~ /^[IAW]$/ || return());
        push(@qparts, $fld);
        push(@qparams, $data->{$fld});
    }
    for $fld (@fldlst_opt) {
        exists($data->{$fld}) || next;
        push(@qparts, $fld);
        push(@qparams, $data->{$fld});
    }

    my $query = 'INSERT INTO invbook_definitions (';
    $query .= join(',', @qparts).') VALUES (';
    $query .= join(',', (map { '?'; } @qparts)).')';

    my $sth = $dbh->prepare($query);
    my $res = $sth->execute(@qparams);
    defined($res) || return();
    return $dbh->{'mysql_insertid'};
}

=head2 ModInvBookDef

    ModInvBookDef($ivbdef);

Updates the content of a given inventory book definition record;
$ivbdef is a hashref whose keys are the fields of the invbook_definitions
table (except: 'invbook_definition_id', 'bookcode', 'type', which are
not editable). The record to modify is determined by
$ivbdef->{invbook_definition_id} parameter (required).

=cut

sub ModInvBookDef {
    my ($data) = @_;

    $data->{'invbook_definition_id'} || return();
    my $dbh = C4::Context->dbh;
    ## invbook_definition_id, bookcode, type: not editable (CHECKME)
    my @fldlst = qw(
        name name_abbrev branchcode
        owned_by active print_format display_format
        numbering_format date_start_of_numbering notes
        page_number_last entry_number_last total_items total_cost
        cn_prefix cn_suffix default_location
        writeoff_basis_seq_number_last writeoff_parent_invbook_defn_id
        number_prefix number_suffix
    );

    my $query = 'UPDATE invbook_definitions SET ';
    my @qparts; my @qparams;
    for my $fld (@fldlst) {
        exists($data->{$fld}) || next;
        push(@qparts, $fld.'=?');
        push(@qparams, $data->{$fld});
    }
    $query .= join(',', @qparts).' WHERE invbook_definition_id=?';
    push(@qparams, $data->{'invbook_definition_id'});
    my $sth = $dbh->prepare($query);
    return $sth->execute(@qparams);
}

=head2 GetInvBookDefDetails

    GetInvBookDefDetails($ibdefid);

Returns specific inventory book definition record identified by $ibdefid.
Result is a hashref containing given record fields from
invbook_definitions table, plus three additional values computed
or derived from associated tables:

    'entries_total_count'
    'entries_total_cost'
    'associated_book_name'

In case of an error (or if the record with the given ID was
not found) it retruns undef.

=cut

sub GetInvBookDefDetails {
    my $id = shift;

    (defined($id) && $id) || return();
    my $bdef = GetInvBookDef($id);
    $bdef || return();

    my $dbh = C4::Context->dbh;
    my $query = '
        SELECT COUNT(*) AS icount, SUM(unitprice) AS isum
        FROM invbook_items WHERE invbook_definition_id = ?
    ';
    $bdef->{type} eq 'A' && do {
        $query = '
            SELECT COUNT(*) AS icount, SUM(total_cost) AS isum
            FROM invbook_accessions WHERE invbook_definition_id = ?
        ';
    };
    $bdef->{type} eq 'W' && do {
        $query = '
            SELECT COUNT(*) AS icount, SUM(total_cost) AS isum
            FROM invbook_writeoffs WHERE invbook_definition_id = ?
        ';
    };
    my ($icount, $icost) = $dbh->selectrow_array($query, {}, $id);
    $icost //= 0.0;
    defined($icount) && do {
        $bdef->{'entries_total_count'} = $icount;
        $bdef->{'entries_total_cost'} = ''.(0.0 + $icost);
    };

    my $siblingbookname = '';
    {
        $bdef->{type} eq 'I' || $bdef->{type} eq 'W' || last;
        $bdef->{writeoff_parent_invbook_defn_id} || last;
        my $sbookdef = GetInvBookDef($bdef->{writeoff_parent_invbook_defn_id});
        ($sbookdef && $sbookdef->{name}) || last;
        $siblingbookname = $sbookdef->{name};
    }
    $bdef->{associated_book_name} = $siblingbookname;

    $bdef;
}

=head2 GetInvBookDef

    GetInvBookDef($ibdefid);

Returns specific inventory book definition record identified by $ibdefid.
Result is a hashref containing given record fields from
invbook_definitions table.

In case of an error (or if the record with the given ID was
not found) it retruns undef.

=cut

sub GetInvBookDef {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $query = '
        SELECT * FROM invbook_definitions
        WHERE invbook_definition_id = ?
    ';
    my $sth = $dbh->prepare($query);
    $sth->execute($id);
    return $sth->fetchrow_hashref();
}

=head2 SearchInvBookDefs

    $results = SearchInvBookDefs($params);

This function returns a reference to the list of hashrefs (one for each
inventory book definition record that meets the conditions specified by
the $params hashref).

All invbook_definitions table fields can be used as search arguments.
See SearchInvBookItems() description for field names suffixes supported
by this function.

Supported special parameters:

1) ORDER_BY, ORDER_BY_DESC, COUNT: see SearchInvBookItems() description
2) DETAILS: if this parameter is defined in $params hashref, this
function will return extended search results like GetInvBookDefDetails().

=cut

sub SearchInvBookDefs {
    my ($params) = @_;

    # field default search criterions
    my $fdsc = {};
    map { $fdsc->{$_} = { txt => 1, trunc => 'TLR' }; } qw(
        name name_abbrev notes
    );
    map { $fdsc->{$_} = { txt => 1, trunc => 'TN' }; } qw(
        bookcode type cn_prefix cn_suffix branchcode default_location
        print_format display_format numbering_format
        number_prefix number_suffix
    );
    map { $fdsc->{$_} = { txt => 0 }; } qw(
        invbook_definition_id owned_by active total_items total_cost
        date_start_of_numbering page_number_last entry_number_last
        writeoff_basis_seq_number_last writeoff_parent_invbook_defn_id
        timestamp_updated
    );
    my $opsql = {
        eq => '=', ne => '<>', gt => '>', ge => '>=', lt => '<', le => '<='
    };
    my $query = '
        SELECT ivd.*
        FROM invbook_definitions ivd
        WHERE 1 = 1
    ';

    my @where_strs; my @q_args;
    for my $fldn (keys %$params) {
        my $trunc=''; my $op='eq';
        my $term = $params->{$fldn};
        $fldn =~ /_(TL|TR|TLR|TN)$/ && do {
            $trunc = $1; $fldn =~ s/_(TL|TR|TLR|TN)$//; };
        $fldn =~ /_(eq|ne|gt|ge|lt|le|rx|rn)$/ && do {
            $op = $1; $fldn =~ s/_(eq|ne|gt|ge|lt|le|rx|rn)$//; };
        defined($fdsc->{$fldn}) || next;
        my $s_fld = 'ivd.'.$fldn;
        my $s_str = '';
        defined($term) || do {
            $s_str = $s_fld.(($op eq 'ne')? ' IS NOT NULL': ' IS NULL');
            push(@where_strs, $s_str);
            next;
        };
        {
            $op =~ /^(eq|ne)$/ || last;
            $fdsc->{$fldn}->{txt} || $trunc ne '' || last;
            $trunc eq '' && do { $trunc = $fdsc->{$fldn}->{trunc}; };
            $trunc =~ /L/ && do { $term = '%'.$term; };
            $trunc =~ /R/ && do { $term .= '%'; };
            $s_str = $s_fld.(($op eq 'ne')? ' NOT LIKE ?': ' LIKE ?');
        }
        {
            ($s_str ne '' && $op =~ /^(rx|rn)$/) || last;
            $s_str = $s_fld.(($op eq 'rn')? ' NOT REGEXP ?': ' REGEXP ?');
        }
        {
            $s_str ne '' && last;
            $s_str = $s_fld.' '.$opsql->{$op}.' ?';
        }
        push(@where_strs, $s_str);
        push(@q_args, $term);
    }

    if (@where_strs) {
        $query .= join(" AND ", "", @where_strs);
    }

    my $order_by = '';
    {
        defined($params->{COUNT}) && last;
        $order_by = $params->{'ORDER_BY_DESC'} // $params->{'ORDER_BY'} // '';
        $order_by eq '' && last;
        defined($fdsc->{$order_by}) || do { $order_by = ''; last; };
        my $order_dir = (defined($params->{'ORDER_BY_DESC'}))? " DESC": " ASC";
        $order_by = 'ivd.'.$order_by.$order_dir;
        $order_by .= ($order_by =~ /invbook_definition_id/)? '': (',ivd.invbook_definition_id'.$order_dir);
        $order_by = " ORDER BY ".$order_by;
    }

    defined($params->{COUNT}) && do {
        $query = "SELECT COUNT(*) AS ResultCount FROM (\n".$query."\n) AS RsTblAlias\n";
    };
    defined($params->{COUNT}) || do {
        $query .= ($order_by ne '')? $order_by: " ORDER BY ivd.invbook_definition_id";
    };

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($query);
    $sth->execute(@q_args);
    my $result = $sth->fetchall_arrayref({});
    (defined($result) && defined($params->{DETAILS})) || return($result);
    [ (map {
        GetInvBookDefDetails($_->{'invbook_definition_id'}) // ();
    } @$result) ];
}

=head2 DelInvBookDef

    DelInvBookDef($ibdefid);

Deletes the inventory book definition record identified by $ibdefid.
Due to the database constrains, it's not possible to delete
inventory book which is not empty (does have 1+ item|accession|writeoff
record[s] associated with it).

Returns undef in case of an error.

=cut

sub DelInvBookDef {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare('
        DELETE FROM invbook_definitions
        WHERE invbook_definition_id = ?
    ');
    return $sth->execute($id);
}


=head2 AddInvBookItem

    $recid = AddInvBookItem($ivbitem);

Creates a new inventory book item record; C<$ivbitem> is a hashref
whose keys are the fields of the invbook_items table. Some
parameters (invbook_definition_id, inventory_number, callnumber,
unitprice, acquisition_mode, accession_id) have to be present.

Returns the unique ID (invbook_item_id) of the newly created item
record or undef in case of an error.

WARNING: accession_id is defined as not NULL in invbook_items
table and as the foreign key from invbook_accessions.. Either
this field should remain mandatory, or the table structure
needs to be updated (???).

=cut

sub AddInvBookItem {
    my ($data) = @_;

    my $dbh = C4::Context->dbh;
    my @fldlst_req = qw(
        invbook_definition_id inventory_number
        callnumber unitprice acquisition_mode
    );
    my @fldlst_opt = qw(
        invbook_item_id biblionumber itemnumber accession_id
        title author publication_place publication_date publication_nr
        notes notes_internal notes_import st_class_1 st_class_2 location
        paging_number paging_item_count_moved_from paging_total_cost_moved_from
        paging_item_count_moved_to paging_total_cost_moved_to
        writeoff_id writeoff_basis_entry_id
        tmp_import_title_hash tmp_import_barcode_hash
        date_added date_printed date_incorporated
        created_by modified_by update_history_log
    );

    my @qparts; my @qparams; my $fld;
    for $fld (@fldlst_req) {
        ## FIXME: better error handling & reporting
        unless (defined($data->{$fld}) && $data->{$fld} ne '') {
            warn "Required field not defined: $fld";
            return();
        }
        push(@qparts, $fld);
        push(@qparams, $data->{$fld});
    }
    for $fld (@fldlst_opt) {
        exists($data->{$fld}) || next;
        push(@qparts, $fld);
        push(@qparams, $data->{$fld});
    }

    my $query = 'INSERT INTO invbook_items (';
    $query .= join(',', @qparts).') VALUES (';
    $query .= join(',', (map { '?'; } @qparts)).')';

    my $sth = $dbh->prepare($query);
    my $res = $sth->execute(@qparams);
    defined($res) || return();
    return $dbh->{'mysql_insertid'};
}

=head2 ModInvBookItem

    ModInvBookItem($ivbitem);

Updates the content of a given inventory book item record; C<$ivbitem>
is a hashref whose keys are the fields of the invbook_items table.
The record to modify is determined by C<$ivbitem-E<gt>{invbook_item_id}>
parameter (required).

=cut

sub ModInvBookItem {
    my ($data) = @_;

    $data->{'invbook_item_id'} || return();
    my $dbh = C4::Context->dbh;
    my @fldlst = qw(
        invbook_definition_id inventory_number accession_id
        biblionumber itemnumber callnumber
        title author publication_place publication_date publication_nr
        notes notes_internal notes_import st_class_1 st_class_2
        unitprice location acquisition_mode
        paging_number paging_item_count_moved_from paging_total_cost_moved_from
        paging_item_count_moved_to paging_total_cost_moved_to
        writeoff_id writeoff_basis_entry_id
        tmp_import_title_hash tmp_import_barcode_hash
        date_added date_printed date_incorporated
        created_by modified_by update_history_log
    );

    my $query = 'UPDATE invbook_items SET ';
    my @qparts; my @qparams;
    for my $fld (@fldlst) {
        exists($data->{$fld}) || next;
        push(@qparts, $fld.'=?');
        push(@qparams, $data->{$fld});
    }
    $query .= join(',', @qparts).' WHERE invbook_item_id=?';
    push(@qparams, $data->{'invbook_item_id'});
    my $sth = $dbh->prepare($query);
    return $sth->execute(@qparams);
}

=head2 GetInvBookItemByID

    GetInvBookItemByID($itemid);

Returns specific inventory book item record identified by $itemid.
Result is a hashref containing given record fields from
invbook_items table.

In case of an error (or if the record with the given ID was
not found) it retruns undef.

=cut

sub GetInvBookItemByID {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $query = 'SELECT * FROM invbook_items WHERE invbook_item_id = ?';
    my $sth = $dbh->prepare($query);
    $sth->execute($id);
    return $sth->fetchrow_hashref();
}

=head2 GetInvBookItemByNumber

    GetInvBookItemByNumber({ bookid => $bkid, invnr => $itemnumber });

Searches for specific inventory book item record identified
by (bookid, invnr) parameter pair. Both parameters are required.
Result is a hashref containing given record fields from
invbook_items table.

In case of an error (or if the desired record was not found)
it retruns undef.

=cut

sub GetInvBookItemByNumber {
    my $params = shift;

    (defined($params->{bookid}) && $params->{bookid}
      && defined($params->{invnr}) && $params->{invnr}) || return();
    my $dbh = C4::Context->dbh;
    my $query = '
        SELECT * FROM invbook_items
        WHERE invbook_definition_id = ? AND inventory_number = ?
    ';
    my $sth = $dbh->prepare($query);
    $sth->execute($params->{bookid}, $params->{ivnr});
    return $sth->fetchrow_hashref();
}

=head2 GetInvBookItemDetails

    GetInvBookItemDetails($itemid);

Like GetInvBookItemByID(); does return some additional / composite
values fetched from linked tables (accession_number, accession_invoice_nr,
biblio_title, biblio_author, biblio_publication_place,
biblio_publication_date, item_callnumber, item_barcode)

=cut

sub GetInvBookItemDetails {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $query = '
        SELECT
            ii.*,
            CONCAT(ia.number_prefix, ia.number_cnt, ia.number_suffix) AS `accession_number`,
            ia.invoice_document_nr AS `accession_invoice_nr`,
            CASE WHEN it.itemnumber IS NOT NULL
               THEN it.itemcallnumber
               ELSE ii.callnumber
            END AS `item_callnumber`,
            it.barcode AS `item_barcode`,
            CASE WHEN b.biblionumber IS NOT NULL
               THEN b.title
               ELSE ii.title
            END AS `biblio_title`,
            CASE WHEN b.biblionumber IS NOT NULL
               THEN b.author
               ELSE ii.author
            END AS `biblio_author`,
            CASE WHEN bi.biblionumber IS NOT NULL
               THEN bi.place
               ELSE ii.publication_place
            END AS `biblio_publication_place`,
            CASE WHEN bi.biblionumber IS NOT NULL
               THEN bi.publicationyear
               ELSE ii.publication_date
            END AS `biblio_publication_date`
        FROM invbook_items ii
        LEFT JOIN invbook_accessions AS ia ON ii.accession_id = ia.accession_id
        LEFT JOIN biblio AS b ON ii.biblionumber = b.biblionumber
        LEFT JOIN biblioitems AS bi ON ii.biblionumber = bi.biblionumber
        LEFT JOIN items AS it ON ii.itemnumber = it.itemnumber
        WHERE invbook_item_id = ?
    ';
    my $sth = $dbh->prepare($query);
    $sth->execute($id);
    return $sth->fetchrow_hashref();
}

=head2 GetInvBookItemInfoByItemNr

    GetInvBookItemInfoByItemNr($itemnumber);

Searches for specific inventory book item record identified
by itemnumber parameter (record ID from items table; required).
Result is a hashref containing given record fields from
invbook_items table plus four additional hashref keys

    bookdef
    accession
    writeoff
    woff_basis_entry

which themselfes are hasrefs, containing further details
regarding inventory book definition, accession record content,
and writeoff / writeoff base entry record contents (if any).

In case of an error (or if the desired record was not found)
it retruns an empty hashref.

=cut

sub GetInvBookItemInfoByItemNr {
    my $itemnumber = shift;

    (defined($itemnumber) && $itemnumber) || return({});
    my $result = SearchInvBookItems( { itemnumber => $itemnumber } );
    ($result && ref($result) eq 'ARRAY' && @$result == 1) || return({});

    my $itemh = $result->[0];
    $itemh->{bookdef} = GetInvBookDef($itemh->{invbook_definition_id});
    $itemh->{accession} = ($itemh->{accession_id})?
        GetInvBookAccession($itemh->{accession_id}): {};
    $itemh->{accession} //= {};

    $itemh->{writeoff} = ($itemh->{writeoff_id})?
        GetInvBookWriteoff($itemh->{writeoff_id}): {};
    $itemh->{writeoff} //= {};

    $itemh->{woff_basis_entry} = ($itemh->{writeoff_basis_entry_id})?
        GetInvBookWfBaseItem($itemh->{writeoff_basis_entry_id}): {};
    $itemh->{woff_basis_entry} //= {};

    exists($itemh->{writeoff}->{invbook_definition_id}) && do {
        $itemh->{wbookdef} = GetInvBookDef($itemh->{writeoff}->{invbook_definition_id});
    };
    $itemh->{wbookdef} //= {};

    $itemh;
}

=head2 SearchInvBookItems

    $results = SearchInvBookItems($params);

This function returns a reference to the list of hashrefs (one for each
inventory item record that meets the conditions specified by the $params
hashref).

All invbook_items table fields can be used as search arguments, along
with some other (composite, derived, ..) [psudo-]fields:

    biblio_title
    biblio_author
    biblio_publication_place
    biblio_publication_date
    accession_number
    accession_invoice_nr
    item_barcode
    item_callnumber

Field names can be suffixed with /_(eq|ne|gt|ge|lt|le|rx|rn)/ to force
usage of the specific SQL operator ('=', '<>', '>', '>=', '<', '<=',
REGEXP, NOT REGEXP). By default, textual fields are being searched with
'LIKE', and numeric fields with '='). If argument value is given as
undef, search will be preformed using 'IS NULL |IS NOT NULL'.

Field names can be further suffixed with /_(TL|TR|TLR|TN)/ to
specify what kind of truncation should be used for 'LIKE' (left, right,
left-and-right, none).

Supported special parameters:

1) LIMIT_FROM, LIMIT_AMOUNT: if specified, "LIMIT $params->{LIMIT_FROM},$params->{LIMIT_AMOUNT}"
will be added to SQL query, so only specified subset of search result can be returned.
In case when LIMIT_AMOUNT is not given in $params, LIMIT_FROM is being ignored.

2) ORDER_BY, ORDER_BY_DESC: could be given to specify result
sorting - each one of the search parameters described above can be used
as sorting criteria, e.g.:

    { ..., ORDER_BY_DESC => 'biblio-title' }

3) COUNT: if this parameter is defined in $params hashref, this
function will not return any real records, but only the single
psuedo-record

    [ { ResultCount => .. } ]

containing total search result count. When using this parameter, all other
special parameters (LIMIT_*, ORDER_*) would be ignored.

=cut

sub SearchInvBookItems {
    my ($params) = @_;

    # field default search criterions
    my $fdsc = {};
    map { $fdsc->{$_} = { txt => 1, trunc => 'TLR' }; } qw(
        title author publication_place publication_date publication_nr
        notes notes_internal notes_import st_class_1 update_history_log
    );
    map { $fdsc->{$_} = { txt => 1, trunc => 'TN' }; } qw(
        callnumber acquisition_mode location st_class_2
        tmp_import_title_hash tmp_import_barcode_hash
    );
    map { $fdsc->{$_} = { txt => 0 }; } qw(
        invbook_item_id invbook_definition_id inventory_number
        accession_id biblionumber itemnumber unitprice
        writeoff_id writeoff_basis_entry_id
        paging_number paging_item_count_moved_from paging_total_cost_moved_from
        paging_item_count_moved_to paging_total_cost_moved_to
        date_added date_printed date_incorporated timestamp_updated
        created_by modified_by
    );
    map { $fdsc->{$_} = { txt => 1, add => 1, trunc => 'TLR' }; } qw(
        biblio_title biblio_author biblio_publication_place biblio_publication_date
    );
    map { $fdsc->{$_} = { txt => 1, add => 1, trunc => 'TN' }; } qw(
        accession_number accession_invoice_nr item_barcode item_callnumber
    );
    my $opsql = {
        eq => '=', ne => '<>', gt => '>', ge => '>=', lt => '<', le => '<='
    };

    my $query = '
        SELECT
            ii.*,
            CONCAT(ia.number_prefix, ia.number_cnt, ia.number_suffix) AS `accession_number`,
            ia.invoice_document_nr AS `accession_invoice_nr`,
            CASE WHEN it.itemnumber IS NOT NULL
               THEN it.itemcallnumber
               ELSE ii.callnumber
            END AS `item_callnumber`,
            it.barcode AS `item_barcode`,
            CASE WHEN b.biblionumber IS NOT NULL
               THEN b.title
               ELSE ii.title
            END AS `biblio_title`,
            CASE WHEN b.biblionumber IS NOT NULL
               THEN b.author
               ELSE ii.author
            END AS `biblio_author`,
            CASE WHEN bi.biblionumber IS NOT NULL
               THEN bi.place
               ELSE ii.publication_place
            END AS `biblio_publication_place`,
            CASE WHEN bi.biblionumber IS NOT NULL
               THEN b.copyrightdate
               ELSE ii.publication_date
            END AS `biblio_publication_date`
        FROM invbook_items ii
        LEFT JOIN invbook_accessions AS ia ON ii.accession_id = ia.accession_id
        LEFT JOIN biblio AS b ON ii.biblionumber = b.biblionumber
        LEFT JOIN biblioitems AS bi ON ii.biblionumber = bi.biblionumber
        LEFT JOIN items AS it ON ii.itemnumber = it.itemnumber
        WHERE 1 = 1
    ';

    my @where_strs; my @having_strs; my @q_args;
    for my $fldn (keys %$params) {
        my $trunc=''; my $op='eq';
        my $term = $params->{$fldn};
        my $or_null = '';
        $fldn =~ /_(ORNULL|ORNOTNULL)$/ && do {
            $or_null = $1; $fldn =~ s/_(ORNULL|ORNOTNULL)$//; };
        $fldn =~ /_(TL|TR|TLR|TN)$/ && do {
            $trunc = $1; $fldn =~ s/_(TL|TR|TLR|TN)$//; };
        $fldn =~ /_(eq|ne|gt|ge|lt|le|rx|rn)$/ && do {
            $op = $1; $fldn =~ s/_(eq|ne|gt|ge|lt|le|rx|rn)$//; };
        defined($fdsc->{$fldn}) || next;
        my $s_fld = ($fdsc->{$fldn}->{add})? '`'.$fldn.'`': 'ii.'.$fldn;
        my $s_str = '';
        defined($term) || do {
            $s_str = $s_fld.(($op eq 'ne')? ' IS NOT NULL': ' IS NULL');
            ($fdsc->{$fldn}->{add})? push(@having_strs, $s_str): push(@where_strs, $s_str);
            next;
        };
        {
            $op =~ /^(eq|ne)$/ || last;
            $fdsc->{$fldn}->{txt} || $trunc ne '' || last;
            $trunc eq '' && do { $trunc = $fdsc->{$fldn}->{trunc}; };
            $trunc =~ /L/ && do { $term = '%'.$term; };
            $trunc =~ /R/ && do { $term .= '%'; };
            $s_str = $s_fld.(($op eq 'ne')? ' NOT LIKE ?': ' LIKE ?');
        }
        {
            ($s_str ne '' && $op =~ /^(rx|rn)$/) || last;
            $s_str = $s_fld.(($op eq 'rn')? ' NOT REGEXP ?': ' REGEXP ?');
        }
        {
            $s_str ne '' && last;
            $s_str = $s_fld.' '.$opsql->{$op}.' ?';
        }
        {
            $or_null eq '' && last;
            $s_str = '('.$s_str.' OR '.$s_fld.' IS '.(($or_null eq 'ORNULL')? '': ' NOT').'NULL)';
        }
        ($fdsc->{$fldn}->{add})? push(@having_strs, $s_str): push(@where_strs, $s_str);
        push(@q_args, $term);
    }

    if (@where_strs) {
        $query .= join(" AND ", "", @where_strs);
    }
    if (@having_strs) {
        $query .= " HAVING " . join(" AND ", @having_strs);
    }

    my $order_by = ''; my $limit_by = '';
    {
        defined($params->{COUNT}) && last;
        $order_by = $params->{'ORDER_BY_DESC'} // $params->{'ORDER_BY'} // '';
        $order_by eq '' && last;
        defined($fdsc->{$order_by}) || do { $order_by = ''; last; };
        $order_by = ($fdsc->{$order_by}->{add})? '`'.$order_by.'`': 'ii.'.$order_by;
        #$order_by .= ($order_by =~ /invbook_item_id/)? '': ',ii.invbook_item_id'; #FIXME: sortowanie nie dziala z dodatkowym parametrem ii.invbook_item_id
        $order_by = " ORDER BY ".$order_by.((defined($params->{'ORDER_BY_DESC'}))? " DESC": "");
    }

    {
        defined($params->{COUNT}) && last;
        (defined($params->{'LIMIT_AMOUNT'}) && $params->{'LIMIT_AMOUNT'}) || last;
        $limit_by = ' LIMIT '.(0+($params->{'LIMIT_FROM'} // 0)).','.(0+$params->{'LIMIT_AMOUNT'});
    }

    defined($params->{COUNT}) && do {
        $query = "SELECT COUNT(*) AS ResultCount FROM (\n".$query."\n) AS RsTblAlias\n";
    };
    defined($params->{COUNT}) || do {
        $query .= ($order_by ne '')? $order_by: " ORDER BY ii.invbook_item_id";
        $query .= $limit_by;
    };

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($query);
    $sth->execute(@q_args);
    return $sth->fetchall_arrayref({});
}

=head2 DelInvBookItem

    DelInvBookItem($itemid);

Deletes the the inventory book item record identified by $itemid.

=cut

sub DelInvBookItem {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare('DELETE FROM invbook_items WHERE invbook_item_id=?');
    return $sth->execute($id);
}


=head2 AddInvBookAccession

    $recid = AddInvBookAccession($ivaitem);

Creates a new inventory book accession record; $ivaitem is a hashref
whose keys are the fields of the invbook_accessions table. Some
parameters (invbook_definition_id, number_cnt, date_accessioned)
have to be present.

Returns the unique ID (accession_id) of the newly created accession
record or undef in case of an error.

=cut

sub AddInvBookAccession {
    my ($data) = @_;

    my $dbh = C4::Context->dbh;
    my @fldlst_req = qw(
        invbook_definition_id number_cnt date_accessioned
    );
    my @fldlst_opt = qw(
        accession_id number_prefix number_suffix total_cost
        invoice_document_nr invoice_id vendor_name vendor_id
        notes notes_import date_entered cost_managed_manually
        created_by modified_by volumes_count fascile_count other_count
        special_count acquisition_mode
    );

    my @qparts; my @qparams; my $fld;
    for $fld (@fldlst_req) {
        (defined($data->{$fld}) && $data->{$fld} ne '') || return();
        push(@qparts, $fld);
        push(@qparams, $data->{$fld});
    }
    for $fld (@fldlst_opt) {
        exists($data->{$fld}) || next;
        push(@qparts, $fld);
        push(@qparams, $data->{$fld});
    }

    my $query = 'INSERT INTO invbook_accessions (';
    $query .= join(',', @qparts).') VALUES (';
    $query .= join(',', (map { '?'; } @qparts)).')';

    my $sth = $dbh->prepare($query);
    my $res = $sth->execute(@qparams);
    defined($res) || return();
    return $dbh->{'mysql_insertid'};
}

=head2 ModInvBookAccession

    ModInvBookAccession($ivaitem);

Updates the content of a given inventory book accession record; $ivaitem
is a hashref whose keys are the fields of the invbook_accessions table.
The record to modify is determined by $ivaitem->{accession_id}
parameter (required).

=cut

sub ModInvBookAccession {
    my ($data) = @_;

    $data->{'accession_id'} || die;#return();
    my $dbh = C4::Context->dbh;
    my @fldlst = qw(
        invbook_definition_id number_cnt date_accessioned
        accession_id number_prefix number_suffix total_cost
        invoice_document_nr invoice_id vendor_name vendor_id
        notes notes_import date_entered cost_managed_manually
        created_by modified_by volumes_count fascile_count other_count
        special_count acquisition_mode
    );

    my $query = 'UPDATE invbook_accessions SET ';
    my @qparts; my @qparams;
    for my $fld (@fldlst) {
        exists($data->{$fld}) || next;
        push(@qparts, $fld.'=?');
        push(@qparams, $data->{$fld});
    }
    $query .= join(',', @qparts).' WHERE accession_id = ?';
    push(@qparams, $data->{'accession_id'});
    my $sth = $dbh->prepare($query);
    return $sth->execute(@qparams);
}

=head2 GetInvBookAccession

    GetInvBookAccession($accrecid);

Returns specific inventory book accession record identified by $accrecid.
Result is a hashref containing given record fields from
invbook_accessions table.

In case of an error (or if the record with the given ID was
not found) it retruns undef.

=cut

sub GetInvBookAccession {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $query = '
        SELECT
            ia.*,
            CONCAT(ia.number_prefix, ia.number_cnt, ia.number_suffix) AS `accession_number`
        FROM invbook_accessions ia
        WHERE accession_id = ?
    ';
    my $sth = $dbh->prepare($query);
    $sth->execute($id);
    return $sth->fetchrow_hashref();
}

=head2 GetInvBookAccessionDetails

    GetInvBookAccessionDetails($accrecid);

Returns specific inventory book accession record identified by $accrecid.
Result is a hashref containing given record fields from invbook_accessions
table plus two additional values computed from associated inventory
item records:

    'entries_total_count'
    'entries_total_cost'

In case of an error (or if the record with the given ID was
not found) it retruns undef.

=cut

sub GetInvBookAccessionDetails {
    my $id = shift;

    (defined($id) && $id) || return();
    my $acc = GetInvBookAccession($id);
    $acc || return();

    my $dbh = C4::Context->dbh;
    my $query = '
        SELECT COUNT(*) AS icount, SUM(unitprice) AS isum
        FROM invbook_items WHERE accession_id = ?
    ';
    my ($icount, $icost) = $dbh->selectrow_array($query, {}, $id);
    $icost //= 0.0;
    defined($icount) && do {
        $acc->{'entries_total_count'} = $icount;
        $acc->{'entries_total_cost'} = ''.(0.0 + $icost);
    };
    $acc;
}

=head2 SearchInvBookAccessions

    $results = SearchInvBookAccessions($params);

This function returns a reference to the list of hashrefs (one for each
inventory book accession record that meets the conditions specified by
the $params hashref). Some additional values are retuned in result
hashref[s] ('entries_total_cost', 'entries_total_count'). Note: those
two additional values can't be used as search/sorting criteria.

All invbook_accessions table fields can be used as search arguments,
along with some other (composite|pseudo) fields:

    accession_number

See SearchInvBookItems() description for field names suffixes supported
by this function.

Special parameters supported by this function include: ORDER_BY,
ORDER_BY_DESC, LIMIT_* and COUNT (See SearchInvBookItems() description
for details).

=cut

sub SearchInvBookAccessions {
    my ($params) = @_;

    # field default search criterions
    my $fdsc = {};
    map { $fdsc->{$_} = { txt => 1, trunc => 'TLR' }; } qw(
        vendor_name notes notes_import
    );
    map { $fdsc->{$_} = { txt => 1, trunc => 'TR' }; } qw(
        invoice_document_nr
    );
    map { $fdsc->{$_} = { txt => 1, trunc => 'TN' }; } qw(
        number_prefix number_suffix acquisition_mode
    );
    map { $fdsc->{$_} = { txt => 0 }; } qw(
        accession_id invbook_definition_id number_cnt
        total_cost invoice_id vendor_id
        date_accessioned date_entered
        cost_managed_manually created_by modified_by
        volumes_count fascile_count other_count special_count
    );
    map { $fdsc->{$_} = { txt => 1, add => 1, trunc => 'TN' }; } qw(
        accession_number
    );
    my $opsql = {
        eq => '=', ne => '<>', gt => '>', ge => '>=', lt => '<', le => '<='
    };
    my $order_expr = {
        accession_number => [ qw(ia.number_suffix ia.number_cnt) ],
    };

    my $query = '
        SELECT
            ia.*,
            CONCAT(ia.number_prefix, ia.number_cnt, ia.number_suffix) AS `accession_number`
        FROM invbook_accessions ia
        WHERE 1 = 1
    ';
    my $query_px = '
        SELECT dta.*,
            COALESCE ((
                SELECT SUM(unitprice) FROM invbook_items ii_a WHERE ii_a.accession_id = dta.accession_id
            ), 0.0) AS entries_total_cost,
            (
                SELECT COUNT(*) FROM invbook_items ii_b WHERE ii_b.accession_id = dta.accession_id
            ) AS entries_total_count
        FROM (
    ';
    my $query_sx = '
        ) AS dta
    ';

    my @where_strs; my @having_strs; my @q_args;
    for my $fldn (keys %$params) {
        my $trunc=''; my $op='eq';
        my $term = $params->{$fldn};
        $fldn =~ /_(TL|TR|TLR|TN)$/ && do {
            $trunc = $1; $fldn =~ s/_(TL|TR|TLR|TN)$//; };
        $fldn =~ /_(eq|ne|gt|ge|lt|le|rx|rn)$/ && do {
            $op = $1; $fldn =~ s/_(eq|ne|gt|ge|lt|le|rx|rn)$//; };
        defined($fdsc->{$fldn}) || next;
        my $s_fld = ($fdsc->{$fldn}->{add})? '`'.$fldn.'`': 'ia.'.$fldn;
        my $s_str = '';
        defined($term) || do {
            $s_str = $s_fld.(($op eq 'ne')? ' IS NOT NULL': ' IS NULL');
            ($fdsc->{$fldn}->{add})? push(@having_strs, $s_str): push(@where_strs, $s_str);
            next;
        };
        {
            $op =~ /^(eq|ne)$/ || last;
            $fdsc->{$fldn}->{txt} || $trunc ne '' || last;
            $trunc eq '' && do { $trunc = $fdsc->{$fldn}->{trunc}; };
            $trunc =~ /L/ && do { $term = '%'.$term; };
            $trunc =~ /R/ && do { $term .= '%'; };
            $s_str = $s_fld.(($op eq 'ne')? ' NOT LIKE ?': ' LIKE ?');
        }
        {
            ($s_str ne '' && $op =~ /^(rx|rn)$/) || last;
            $s_str = $s_fld.(($op eq 'rn')? ' NOT REGEXP ?': ' REGEXP ?');
        }
        {
            $s_str ne '' && last;
            $s_str = $s_fld.' '.$opsql->{$op}.' ?';
        }
        push(@q_args, $term);
        ($fdsc->{$fldn}->{add})? push(@having_strs, $s_str): push(@where_strs, $s_str);
    }

    if (@where_strs) {
        $query .= join(" AND ", "", @where_strs);
    }
    if (@having_strs) {
        $query .= " HAVING " . join(" AND ", @having_strs);
    }

    my $order_by = ''; my $limit_by = '';
    {
        defined($params->{COUNT}) && last;
        $order_by = $params->{'ORDER_BY_DESC'} // $params->{'ORDER_BY'} // '';
        $order_by eq '' && last;
        defined($fdsc->{$order_by}) || do { $order_by = ''; last; };
        if (defined($order_expr->{$order_by})) {
            $order_by = " ORDER BY ".join(',',(map { $_.(defined($params->{ORDER_BY_DESC})? " DESC": ""); } @{$order_expr->{$order_by}}));
        } else {
            $order_by = ($fdsc->{$order_by}->{add})? $order_by: 'ia.'.$order_by;
            $order_by = " ORDER BY ".$order_by.((defined($params->{'ORDER_BY_DESC'}))? " DESC": "");
        }
    }

    {
        defined($params->{COUNT}) && last;
        (defined($params->{'LIMIT_AMOUNT'}) && $params->{'LIMIT_AMOUNT'}) || last;
        $limit_by = ' LIMIT '.(0+($params->{'LIMIT_FROM'} // 0)).','.(0+$params->{'LIMIT_AMOUNT'});
    }

    defined($params->{COUNT}) && do {
        $query = "SELECT COUNT(*) AS ResultCount FROM (\n".$query."\n) AS RsTblAlias\n";
    };
    defined($params->{COUNT}) || do {
        $query .= ($order_by ne '')? $order_by: " ORDER BY ia.accession_id";
        $query .= $limit_by;
        $query = $query_px.$query.$query_sx;
    };

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($query);
    $sth->execute(@q_args);
    return $sth->fetchall_arrayref({});
}

=head2 DelInvBookAccession

    DelInvBookAccession($accrecid);

Deletes the inventory book accession record identified by $accrecid.
Due to the database constrains, it's not possible to delete
accession record which does have 1+ inventory book item record[s]
associated with it.

Returns undef in case of an error.

=cut

sub DelInvBookAccession {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare('
        DELETE FROM invbook_accessions
        WHERE accession_id = ?
    ');
    return $sth->execute($id);
}

=head2 GetLastAccessionInfo

    GetLastAccessionInfo($inv_book_id);

Returns info about last accesioned item from specifed accession book.

=cut

sub GetLastAccessionInfo {
    my $acc_book_id = shift;

    (defined($acc_book_id) && $acc_book_id) || return();
    my $dbh = C4::Context->dbh;
    my $last_id = $dbh->selectcol_arrayref('SELECT accession_id FROM invbook_accessions
            WHERE invbook_definition_id = ? ORDER BY accession_id DESC
            LIMIT 1', undef, $acc_book_id );

    return GetInvBookAccession( @$last_id );
}

=head2 GetNextAccessionInfo


    TODO: wszystko

=cut

sub GetNextAccessionNumber {
    my $acc_book_id = shift;

    (defined($acc_book_id) && $acc_book_id) || return();
    my $info = GetLastAccessionInfo($acc_book_id);
    my %nextAccNumb;
    $nextAccNumb{prefix} = $info->{'number_prefix'};
    $nextAccNumb{number}  = ++$info->{'number_cnt'};
    $nextAccNumb{suffix}  = $info->{'number_suffix'};

    return (\%nextAccNumb)
        unless (C4::Context->preference("InventoryBookVariant") && C4::Context->preference("InventoryBookVariant") eq 'BPK');

    my $bookdef = GetInvBookDef($acc_book_id);
    $nextAccNumb{prefix} = $bookdef->{number_prefix} // '';
    return \%nextAccNumb;
}

=head2 GetNextInventoryNumber

    TODO: sprawdzanie czy numer ok.

=cut

sub GetNextInventoryNumber {
    my $inv_book_id = shift;

    (defined $inv_book_id && $inv_book_id) || return();

    my $dbh = C4::Context->dbh;
    my $number = $dbh->selectcol_arrayref(
            "SELECT MAX(inventory_number)
            FROM invbook_items
            WHERE invbook_definition_id = ?", undef, $inv_book_id);

    $number->[0]++;
    #check if next number exist in inventory, this shouldn't happend
    #but if this number already exists search for next number.
#    my $result;
#    do {
#        #next number in inv book
#        $number->[0]++;
#        $result = SearchInvBookItems({
#            invbook_definition_id => $inv_book_id,
#            inventory_number      => $number->[0],
#            });
#    } while ( defined ( @$result ));


    my $prefix  = $dbh->selectcol_arrayref( "SELECT number_prefix, number_suffix FROM invbook_definitions WHERE invbook_definition_id = ?", { Columns => [1,2] } , $inv_book_id);
    return ($number, $prefix->[0] // '', $prefix->[1] // ''); #prefix suffix?
}

=head2 GetNextWriteoffNumbers

    $nextnums = GetNextWriteoffNumbers($woff_book_id);

For a given writeoff book identified by $woff_book_id, this
function returns a hashref containing next avaliable
unused registry number (writeoff_number) and proposed next
base document prefix | number | sufdix combo, in the following
format:

    { number => .., base_prefix => .., base_cnt => .., base_suffix => .. }

Note that, while registry / writeoff number returned is pretty much
guaranted to be free and unused, it's not necessarily always the case
for base document number components (which are freely user-editable).
If next unused base number can't be guessed/determined, base_cnt value
retuned would be an empty string.

In case of a fatal error, it returns undef.

=cut

sub GetNextWriteoffNumbers {
    my $inv_book_id = shift;

    (defined $inv_book_id && $inv_book_id) || return();

    my $dbh = C4::Context->dbh;
    my $number = $dbh->selectcol_arrayref(
            "SELECT MAX(writeoff_number)
            FROM invbook_writeoffs
            WHERE invbook_definition_id = ?", undef, $inv_book_id);

    my $nextnum = { number => 1, base_prefix => '', base_cnt => 1, base_suffix => '' };
    my $bookdef = GetInvBookDef($inv_book_id);
    $bookdef || return($nextnum);

    $nextnum->{base_prefix} = $bookdef->{number_prefix} // '';
    $nextnum->{base_suffix} = $bookdef->{number_suffix} // '';

    (defined @$number[0] && @$number == 1) || return($nextnum);
    $nextnum->{number} = 1 + $number->[0];

    my $sresult = SearchInvBookWriteoffs({
        invbook_definition_id => $inv_book_id,
        writeoff_number => $number->[0],
    });
    ($sresult && @$sresult == 1) || do {
        $nextnum->{base_cnt} = '';
        return($nextnum);
    };

    $nextnum->{base_prefix} = $sresult->[0]->{base_document_number_prefix} // '';
    $nextnum->{base_cnt} = 1 + $sresult->[0]->{base_document_number_cnt};
    $nextnum->{base_suffix} = $sresult->[0]->{base_document_number_suffix} // '';

    my $dresult = SearchInvBookWriteoffs({
        invbook_definition_id => $inv_book_id,
        base_document_number_prefix => $nextnum->{base_prefix},
        base_document_number_cnt => $nextnum->{base_cnt},
        base_document_number_suffix => $nextnum->{base_suffix},
    });
    $dresult && @$dresult && do {
        ## duplicate
        $nextnum->{base_cnt} = '';
        return($nextnum);
    };

    $nextnum;
}

=head2 AddInvBookWriteoff

    $recid = AddInvBookWriteoff($iv_woff);

Creates a new inventory book writeoff entry record; $iv_woff is a hashref
whose keys are the fields of the invbook_writeoffs table. Some parameters
(invbook_definition_id, writeoff_number, reason, date_writeoff) have
to be present.

Returns the unique ID (writeoff_id) of the newly created writeoff
record or undef in case of an error.

=cut

sub AddInvBookWriteoff {
    my ($data) = @_;

    my $dbh = C4::Context->dbh;
    my @fldlst_req = qw(
        invbook_definition_id writeoff_number reason date_writeoff
    );
    my @fldlst_opt = qw(
        base_document_number_prefix base_document_number_cnt
        base_document_number_suffix base_document_description
        notes notes_internal notes_import total_cost unit_count
        current_status date_document date_printed
        cost_managed_manually count_managed_manually
        paging_number paging_total_cost_moved_from paging_total_cost_moved_to
        created_by modified_by
    );

    my @qparts; my @qparams; my $fld;
    for $fld (@fldlst_req) {
        unless (defined($data->{$fld}) && $data->{$fld} ne '') {
            warn "Missing required field: $fld";
            return();
        }
        push(@qparts, $fld);
        push(@qparams, $data->{$fld});
    }
    for $fld (@fldlst_opt) {
        exists($data->{$fld}) || next;
        push(@qparts, $fld);
        push(@qparams, $data->{$fld});
    }

    my $query = 'INSERT INTO invbook_writeoffs (';
    $query .= join(',', @qparts).') VALUES (';
    $query .= join(',', (map { '?'; } @qparts)).')';

    my $sth = $dbh->prepare($query);
    my $res = $sth->execute(@qparams);
    defined($res) || return();
    return $dbh->{'mysql_insertid'};
}

=head2 ModInvBookWriteoff

    ModInvBookWriteoff($iv_woff);

Updates the content of a given inventory book writeoff record; $iv_woff
is a hashref whose keys are the fields of the invbook_writeoffs table.
The record to modify is determined by $iv_woff->{writeoff_id}
parameter (required).

In case of an error it retuns undef; 1 on success; 0E0 if the record
with given ID does not exist.

=cut

sub ModInvBookWriteoff {
    my ($data) = @_;

    $data->{'writeoff_id'} || return();
    my $dbh = C4::Context->dbh;
    my @fldlst = qw(
        invbook_definition_id writeoff_number reason date_writeoff
        base_document_number_prefix base_document_number_cnt
        base_document_number_suffix base_document_description
        notes notes_internal notes_import total_cost unit_count
        current_status date_document date_printed
        cost_managed_manually count_managed_manually
        paging_number paging_total_cost_moved_from paging_total_cost_moved_to
        created_by modified_by
    );

    my $query = 'UPDATE invbook_writeoffs SET ';
    my @qparts; my @qparams;
    for my $fld (@fldlst) {
        exists($data->{$fld}) || next;
        push(@qparts, $fld.'=?');
        push(@qparams, $data->{$fld});
    }
    $query .= join(',', @qparts).' WHERE writeoff_id = ?';
    push(@qparams, $data->{'writeoff_id'});
    my $sth = $dbh->prepare($query);
    return $sth->execute(@qparams);
}

=head2 GetInvBookWriteoff

    GetInvBookWriteoff($woffid);

Returns specific inventory book writeoff record identified by $woffid.
Result is a hashref containing given record fields from invbook_writeoffs
table, plus one pseudo/composite field 'base_document_number'.

In case of an error (or if the record with the given ID was
not found) it returns undef.

=cut

sub GetInvBookWriteoff {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $query = '
        SELECT
            iw.*,
            CONCAT(iw.base_document_number_prefix, iw.base_document_number_cnt, iw.base_document_number_suffix) AS `base_document_number`
        FROM invbook_writeoffs iw
        WHERE writeoff_id = ?
    ';
    my $sth = $dbh->prepare($query);
    $sth->execute($id);
    return $sth->fetchrow_hashref();
}

=head2 GetInvBookWriteoffDetails

    GetInvBookWriteoffDetails($woffid);

Returns specific inventory book writeoff record identified by $woffid.
Result is a hashref containing given record fields from invbook_writeoffs
table, plus one pseudo/composite field 'base_document_number' and
two additional values computed from associated inventory item records

    'entries_unit_count'
    'entries_total_cost'

In case of an error (or if the record with the given ID was
not found) it retruns undef.

=cut

sub GetInvBookWriteoffDetails {
    my $id = shift;

    (defined($id) && $id) || return();
    my $woff = GetInvBookWriteoff($id);
    $woff || return();

    my $dbh = C4::Context->dbh;
    my $query = '
        SELECT COUNT(*) AS icount, SUM(unitprice) AS isum
        FROM invbook_items WHERE writeoff_id = ?
    ';
    my ($icount, $icost) = $dbh->selectrow_array($query, {}, $id);
    $icost //= 0.0;
    defined($icount) && do {
        $woff->{'entries_unit_count'} = $icount;
        $woff->{'entries_total_cost'} = ''.(0.0 + $icost);
    };
    $woff;
}

=head2 SearchInvBookWriteoffs

    $results = SearchInvBookWriteoffs($params);

This function returns a reference to the list of hashrefs (one for each
inventory book writeoff record that meets the conditions specified by
the $params hashref). Some additional values are retuned in result
hashref[s] ('entries_total_cost', 'entries_unit_count'). Note: those
two additional values can't be used as search/sorting criteria.

All invbook_writeoffs table fields can be used as search arguments,
along with some other (composite|pseudo) fields:

    base_document_number
    base_seq_nr_first_last

See SearchInvBookItems() description for field names suffixes supported
by this function.

Special parameters supported by this function include: ORDER_BY,
ORDER_BY_DESC, LIMIT_* and COUNT (See SearchInvBookItems() description
for details).

=cut

sub SearchInvBookWriteoffs {
    my ($params) = @_;

    # field default search criterions
    my $fdsc = {};
    map { $fdsc->{$_} = { txt => 1, trunc => 'TLR' }; } qw(
        notes notes_internal notes_import base_document_description
    );
    map { $fdsc->{$_} = { txt => 1, trunc => 'TN' }; } qw(
        base_document_number_prefix base_document_number_suffix
        current_status reason
    );
    map { $fdsc->{$_} = { txt => 0 }; } qw(
        writeoff_id invbook_definition_id writeoff_number base_document_number_cnt
        date_writeoff date_document date_printed
        cost_managed_manually count_managed_manually
        paging_number paging_total_cost_moved_from paging_total_cost_moved_to
        total_cost unit_count
        created_by modified_by
    );
    map { $fdsc->{$_} = { txt => 1, add => 1, trunc => 'TN' }; } qw(
        base_document_number
    );
    my $opsql = {
        eq => '=', ne => '<>', gt => '>', ge => '>=', lt => '<', le => '<='
    };
    my $order_expr = {
        base_document_number => [ qw(iw.base_document_number_prefix iw.base_document_number_cnt iw.base_document_number_suffix) ],
    };

    my $query = '
        SELECT
            iw.*,
            CONCAT(iw.base_document_number_prefix, iw.base_document_number_cnt, iw.base_document_number_suffix) AS `base_document_number`
        FROM invbook_writeoffs iw
        WHERE 1 = 1
    ';
    my $query_px = '
        SELECT dtw.*,
            COALESCE ((
                SELECT SUM(unitprice) FROM invbook_items ii_a WHERE ii_a.writeoff_id = dtw.writeoff_id
            ), 0.0) AS entries_total_cost,
            (
                SELECT COUNT(*) FROM invbook_items ii_b WHERE ii_b.writeoff_id = dtw.writeoff_id
            ) AS entries_unit_count,
            (
                SELECT CONCAT(MIN(seq_number), " - ", MAX(seq_number)) FROM invbook_writeoff_bases iwb_a WHERE iwb_a.writeoff_id = dtw.writeoff_id
            ) AS base_seq_nr_first_last
        FROM (
    ';
    my $query_sx = '
        ) AS dtw
    ';

    my @where_strs; my @having_strs; my @q_args;
    for my $fldn (keys %$params) {
        my $trunc=''; my $op='eq';
        my $term = $params->{$fldn};
        $fldn =~ /_(TL|TR|TLR|TN)$/ && do {
            $trunc = $1; $fldn =~ s/_(TL|TR|TLR|TN)$//; };
        $fldn =~ /_(eq|ne|gt|ge|lt|le|rx|rn)$/ && do {
            $op = $1; $fldn =~ s/_(eq|ne|gt|ge|lt|le|rx|rn)$//; };
        defined($fdsc->{$fldn}) || next;
        my $s_fld = ($fdsc->{$fldn}->{add})? '`'.$fldn.'`': 'iw.'.$fldn;
        my $s_str = '';
        defined($term) || do {
            $s_str = $s_fld.(($op eq 'ne')? ' IS NOT NULL': ' IS NULL');
            ($fdsc->{$fldn}->{add})? push(@having_strs, $s_str): push(@where_strs, $s_str);
            next;
        };
        {
            $op =~ /^(eq|ne)$/ || last;
            $fdsc->{$fldn}->{txt} || $trunc ne '' || last;
            $trunc eq '' && do { $trunc = $fdsc->{$fldn}->{trunc}; };
            $trunc =~ /L/ && do { $term = '%'.$term; };
            $trunc =~ /R/ && do { $term .= '%'; };
            $s_str = $s_fld.(($op eq 'ne')? ' NOT LIKE ?': ' LIKE ?');
        }
        {
            ($s_str ne '' && $op =~ /^(rx|rn)$/) || last;
            $s_str = $s_fld.(($op eq 'rn')? ' NOT REGEXP ?': ' REGEXP ?');
        }
        {
            $s_str ne '' && last;
            $s_str = $s_fld.' '.$opsql->{$op}.' ?';
        }
        push(@q_args, $term);
        ($fdsc->{$fldn}->{add})? push(@having_strs, $s_str): push(@where_strs, $s_str);
    }

    if (@where_strs) {
        $query .= join(" AND ", "", @where_strs);
    }
    if (@having_strs) {
        $query .= " HAVING " . join(" AND ", @having_strs);
    }

    my $order_by = ''; my $limit_by = '';
    {
        defined($params->{COUNT}) && last;
        $order_by = $params->{'ORDER_BY_DESC'} // $params->{'ORDER_BY'} // '';
        $order_by eq '' && last;
        defined($fdsc->{$order_by}) || do { $order_by = ''; last; };
        if (defined($order_expr->{$order_by})) {
            $order_by = " ORDER BY ".join(',',(map { $_.(defined($params->{ORDER_BY_DESC})? " DESC": ""); } @{$order_expr->{$order_by}}));
        } else {
            $order_by = ($fdsc->{$order_by}->{add})? $order_by: 'iw.'.$order_by;
            $order_by = " ORDER BY ".$order_by.((defined($params->{'ORDER_BY_DESC'}))? " DESC": "");
        }
    }

    {
        defined($params->{COUNT}) && last;
        (defined($params->{'LIMIT_AMOUNT'}) && $params->{'LIMIT_AMOUNT'}) || last;
        $limit_by = ' LIMIT '.(0+($params->{'LIMIT_FROM'} // 0)).','.(0+$params->{'LIMIT_AMOUNT'});
    }

    defined($params->{COUNT}) && do {
        $query = "SELECT COUNT(*) AS ResultCount FROM (\n".$query."\n) AS RsTblAlias\n";
    };
    defined($params->{COUNT}) || do {
        $query .= ($order_by ne '')? $order_by: " ORDER BY iw.writeoff_id";
        $query .= $limit_by;
        $query = $query_px.$query.$query_sx;
    };

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($query);
    $sth->execute(@q_args);
    return $sth->fetchall_arrayref({});
}

=head2 DelInvBookWriteoff

    DelInvBookWriteoff($woffid);

Deletes the inventory book writeoff record identified by $woffid.
Note: due to the ivbook_* tables constrains being currently
messed up beyond recognition, it may be, like, totally possible to delete
writeoff record which does have 1+ inventory book item record[s] - or even
invbook_writeoff_bases - associated with it (so: better be, like,
super/hiper/extra carefull if you have a desire for deleting any
writeoff records whatsoever).

Returns undef in case of an error.

=cut

sub DelInvBookWriteoff {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare('
        DELETE FROM invbook_writeoffs
        WHERE writeoff_id = ?
    ');
    return $sth->execute($id);
}

=head2 AddInvBookWfBaseItem

    $recid = AddInvBookWfBaseItem($iv_wfbi);

Creates a new inventory book writeoff base item / entry record; $iv_wfbi
is a hashref whose keys are the fields of the invbook_writeoff_bases
table. Some parameters (invbook_definition_id, writeoff_id, date_added)
have to be present.

Returns the unique ID (writeoff_basis_entry_id) of the newly created
writeoff base item record or undef in case of an error.

CHECKME: is date_added really needed / necessary ???

=cut

sub AddInvBookWfBaseItem {
    my ($data) = @_;

    my $dbh = C4::Context->dbh;
    my @fldlst_req = qw(
        invbook_definition_id writeoff_id date_added
    );
    my @fldlst_opt = qw(
        invbook_item_id seq_number
        notes notes_internal notes_import
        paging_number paging_total_cost_moved_from paging_total_cost_moved_to
        date_printed
        created_by modified_by
    );

    my @qparts; my @qparams; my $fld;
    for $fld (@fldlst_req) {
        (defined($data->{$fld}) && $data->{$fld} ne '') || return();
        push(@qparts, $fld);
        push(@qparams, $data->{$fld});
    }
    for $fld (@fldlst_opt) {
        exists($data->{$fld}) || next;
        push(@qparts, $fld);
        push(@qparams, $data->{$fld});
    }

    my $query = 'INSERT INTO invbook_writeoff_bases (';
    $query .= join(',', @qparts).') VALUES (';
    $query .= join(',', (map { '?'; } @qparts)).')';

    my $sth = $dbh->prepare($query);
    my $res = $sth->execute(@qparams);
    defined($res) || return();
    return $dbh->{'mysql_insertid'};
}

=head2 ModInvBookWfBaseItem

    ModInvBookWfBaseItem($iv_wfbi);

Updates the content of a given inventory book writeoff base item record;
$iv_wfbi is a hashref whose keys are the fields of the invbook_writeoff_bases
table. The record to modify is determined by $iv_wfbi->{writeoff_basis_entry_id}
parameter (required).

In case of an error it retuns undef; 1 on success; 0E0 if the record
with given ID does not exist.

=cut

sub ModInvBookWfBaseItem {
    my ($data) = @_;

    $data->{'writeoff_basis_entry_id'} || return();
    my $dbh = C4::Context->dbh;
    my @fldlst = qw(
        invbook_definition_id writeoff_id invbook_item_id date_added
        seq_number notes notes_internal notes_import
        paging_number paging_total_cost_moved_from paging_total_cost_moved_to
        date_added date_printed
        created_by modified_by
    );

    my $query = 'UPDATE invbook_writeoff_bases SET ';
    my @qparts; my @qparams;
    for my $fld (@fldlst) {
        exists($data->{$fld}) || next;
        push(@qparts, $fld.'=?');
        push(@qparams, $data->{$fld});
    }
    $query .= join(',', @qparts).' WHERE writeoff_basis_entry_id = ?';
    push(@qparams, $data->{'writeoff_basis_entry_id'});
    my $sth = $dbh->prepare($query);
    return $sth->execute(@qparams);
}

=head2 GetInvBookWfBaseItem

    GetInvBookWfBaseItem($wfbid);

Returns specific inventory book writeoff base item record identified
by $wfbid. Result is a hashref containing given record fields from
invbook_writeoff_bases table.

In case of an error (or if the record with the given ID was
not found) it returns undef.

=cut

sub GetInvBookWfBaseItem {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $query = '
        SELECT
            iwbi.*
        FROM invbook_writeoff_bases iwbi
        WHERE writeoff_basis_entry_id = ?
    ';
    my $sth = $dbh->prepare($query);
    $sth->execute($id);
    return $sth->fetchrow_hashref();
}

=head2 GetInvBookWfBaseItemDetails

    GetInvBookWfBaseItemDetails($wfbid);

Returns specific inventory book writeoff base item record identified
by $wfbid. Result is a hashref containing given record fields from
invbook_writeoff_bases table, plus two additional pseudo keys
(hashrefs) 'writeoff_details' and 'item_details', containing data fetched
from associated writeoff and inventory item records respectivelly.

See GetInvBookItemDetails() and GetInvBookWriteoffDetails() descriptions
to determine what kinds of values you can expect in additional hashrefs
referenced by 'writeoff_details' and 'item_details' hashref keys.

In case of an error (or if the record with the given ID was not found)
it returns undef.

=cut

sub GetInvBookWfBaseItemDetails {
    my $id = shift;

    (defined($id) && $id) || return();
    my $woff = GetInvBookWfBaseItem($id);
    $woff || return();

    $woff->{item_details} = ($woff->{invbook_item_id})? GetInvBookItemDetails($woff->{invbook_item_id}): {};
    $woff->{writeoff_details} = GetInvBookWriteoffDetails($woff->{writeoff_id});

    $woff;
}

=head2 SearchInvBookWfBaseItems

    $results = SearchInvBookWfBaseItems($params);

This function returns a reference to the list of hashrefs (one for each
inventory book writeoff base item record that meets the conditions
specified by the $params hashref). If 'DETAILS' parameter is defined
in $params hashref, this function will return extended search results
like GetInvBookWfBaseItemDetails() does.

All invbook_writeoff_bases table fields can be used as search arguments,
along with some other (composite, derived, ...) [pseudo-]fields:

    base_document_number
    base_document_description
    base_document_number_prefix
    base_document_number_cnt
    base_document_number_suffix
    current_status
    reason
    date_document
    date_writeoff
    writeoff_date_printed

    biblio_title
    biblio_author
    biblio_publication_place
    biblio_publication_date

    item_barcode
    item_callnumber

    accession_number
    accession_invoice_nr


See SearchInvBookItems() description for field names suffixes supported
by this function.

Special parameters supported by this function include: ORDER_BY,
ORDER_BY_DESC, LIMIT_* and COUNT (See SearchInvBookItems() description
for details).

=cut

sub SearchInvBookWfBaseItems {
    my ($params) = @_;

    # field default search criterions
    my $fdsc = {};
    map { $fdsc->{$_} = { txt => 1, trunc => 'TLR' }; } qw(
        notes notes_internal notes_import base_document_description
    );
    map { $fdsc->{$_} = { txt => 1, trunc => 'TN' }; } qw(
        base_document_number_prefix base_document_number_suffix
        current_status reason
    );
    map { $fdsc->{$_} = { txt => 0 }; } qw(
        writeoff_basis_entry_id invbook_definition_id
        writeoff_id invbook_item_id seq_number
        writeoff_number base_document_number_cnt
        date_added date_printed
        date_document date_writeoff writeoff_date_printed
        paging_number paging_total_cost_moved_from paging_total_cost_moved_to
        created_by modified_by
    );
    map { $fdsc->{$_} = { txt => 1, add => 1, trunc => 'TN' }; } qw(
        base_document_number
        accession_number accession_invoice_nr
        item_barcode item_callnumber
    );
    map { $fdsc->{$_} = { txt => 1, add => 1, trunc => 'TLR' }; } qw(
        biblio_title biblio_author
        biblio_publication_place biblio_publication_date
    );

    my $opsql = {
        eq => '=', ne => '<>', gt => '>', ge => '>=', lt => '<', le => '<='
    };
    my $order_expr = {
        base_document_number => [ qw(iw.base_document_number_prefix iw.base_document_number_cnt iw.base_document_number_suffix) ],
        accession_number => [ qw(ia.number_prefix ia.number_suffix ia.number_cnt) ],
    };

    my $query = '
        SELECT
            iwbi.*,
            iw.writeoff_number,
            iw.base_document_number_prefix,
            iw.base_document_number_cnt,
            iw.base_document_number_suffix,
            iw.base_document_description,
            iw.reason,
            iw.current_status,
            iw.date_document,
            iw.date_writeoff,
            iw.date_printed AS `writeoff_date_printed`,
            CONCAT(iw.base_document_number_prefix, iw.base_document_number_cnt, iw.base_document_number_suffix) AS `base_document_number`,
            CASE WHEN it.itemnumber IS NOT NULL
               THEN it.itemcallnumber
               ELSE ii.callnumber
            END AS `item_callnumber`,
            it.barcode AS `item_barcode`,
            CASE WHEN b.biblionumber IS NOT NULL
               THEN b.title
               ELSE ii.title
            END AS `biblio_title`,
            CASE WHEN b.biblionumber IS NOT NULL
               THEN b.author
               ELSE ii.author
            END AS `biblio_author`,
            CASE WHEN bi.biblionumber IS NOT NULL
               THEN bi.place
               ELSE ii.publication_place
            END AS `biblio_publication_place`,
            CASE WHEN bi.biblionumber IS NOT NULL
               THEN b.copyrightdate
               ELSE ii.publication_date
            END AS `biblio_publication_date`,
            CONCAT(ia.number_prefix, ia.number_cnt, ia.number_suffix) AS `accession_number`,
            ia.invoice_document_nr AS `accession_invoice_nr`
        FROM invbook_writeoff_bases iwbi
        LEFT JOIN invbook_writeoffs AS iw ON iwbi.writeoff_id = iw.writeoff_id
        LEFT JOIN invbook_items AS ii ON iwbi.invbook_item_id = ii.invbook_item_id
        LEFT JOIN invbook_accessions AS ia ON ii.accession_id = ia.accession_id
        LEFT JOIN biblio AS b ON ii.biblionumber = b.biblionumber
        LEFT JOIN biblioitems AS bi ON ii.biblionumber = bi.biblionumber
        LEFT JOIN items AS it ON ii.itemnumber = it.itemnumber
        WHERE 1 = 1
    ';

    my @where_strs; my @having_strs; my @q_args;
    for my $fldn (keys %$params) {
        my $trunc=''; my $op='eq';
        my $term = $params->{$fldn};
        $fldn =~ /_(TL|TR|TLR|TN)$/ && do {
            $trunc = $1; $fldn =~ s/_(TL|TR|TLR|TN)$//; };
        $fldn =~ /_(eq|ne|gt|ge|lt|le|rx|rn)$/ && do {
            $op = $1; $fldn =~ s/_(eq|ne|gt|ge|lt|le|rx|rn)$//; };
        defined($fdsc->{$fldn}) || next;
        my $s_fld = ($fdsc->{$fldn}->{add})? '`'.$fldn.'`': 'iw.'.$fldn;
        my $s_str = '';
        defined($term) || do {
            $s_str = $s_fld.(($op eq 'ne')? ' IS NOT NULL': ' IS NULL');
            ($fdsc->{$fldn}->{add})? push(@having_strs, $s_str): push(@where_strs, $s_str);
            next;
        };
        {
            $op =~ /^(eq|ne)$/ || last;
            $fdsc->{$fldn}->{txt} || $trunc ne '' || last;
            $trunc eq '' && do { $trunc = $fdsc->{$fldn}->{trunc}; };
            $trunc =~ /L/ && do { $term = '%'.$term; };
            $trunc =~ /R/ && do { $term .= '%'; };
            $s_str = $s_fld.(($op eq 'ne')? ' NOT LIKE ?': ' LIKE ?');
        }
        {
            ($s_str ne '' && $op =~ /^(rx|rn)$/) || last;
            $s_str = $s_fld.(($op eq 'rn')? ' NOT REGEXP ?': ' REGEXP ?');
        }
        {
            $s_str ne '' && last;
            $s_str = $s_fld.' '.$opsql->{$op}.' ?';
        }
        push(@q_args, $term);
        ($fdsc->{$fldn}->{add})? push(@having_strs, $s_str): push(@where_strs, $s_str);
    }

    if (@where_strs) {
        $query .= join(" AND ", "", @where_strs);
    }
    if (@having_strs) {
        $query .= " HAVING " . join(" AND ", @having_strs);
    }

    my $order_by = ''; my $limit_by = '';
    {
        defined($params->{COUNT}) && last;
        $order_by = $params->{'ORDER_BY_DESC'} // $params->{'ORDER_BY'} // '';
        $order_by eq '' && last;
        defined($fdsc->{$order_by}) || do { $order_by = ''; last; };
        ## FIXME ?
        if (defined($order_expr->{$order_by})) {
            $order_by = " ORDER BY ".join(',',(map { $_.(defined($params->{ORDER_BY_DESC})? " DESC": ""); } @{$order_expr->{$order_by}}));
        } else {
            $order_by = ($fdsc->{$order_by}->{add})? $order_by: 'iwbi.'.$order_by;
            $order_by = " ORDER BY ".$order_by.((defined($params->{'ORDER_BY_DESC'}))? " DESC": "");
        }
    }

    {
        defined($params->{COUNT}) && last;
        (defined($params->{'LIMIT_AMOUNT'}) && $params->{'LIMIT_AMOUNT'}) || last;
        $limit_by = ' LIMIT '.(0+($params->{'LIMIT_FROM'} // 0)).','.(0+$params->{'LIMIT_AMOUNT'});
    }

    defined($params->{COUNT}) && do {
        $query = "SELECT COUNT(*) AS ResultCount FROM (\n".$query."\n) AS RsTblAlias\n";
    };
    ## FIXME ?
    defined($params->{COUNT}) || do {
        $query .= ($order_by ne '')? $order_by: " ORDER BY iwbi.writeoff_basis_entry_id";
        $query .= $limit_by;
    };

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($query);
    $sth->execute(@q_args);
    my $result = $sth->fetchall_arrayref({});

    (defined($result) && defined($params->{DETAILS})) || return($result);
    [ (map {
        GetInvBookWfBaseItemDetails($_->{'writeoff_basis_entry_id'}) // ();
    } @$result) ];
}

=head2 DelInvBookWfBaseItem

    DelInvBookWfBaseItem($wfbid);

Deletes the inventory book writeoff base item record identified by $wfbid.
Note: due to the ivbook_* tables constrains being currently
messed up beyond recognition, it may be, like, totally possible to delete
writeoff base item record which does have inventory book item record
associated with it (so: better be, like, super/hiper/extra carefull if you
have a desire for deleting any writeoff base item records whatsoever).

Returns undef in case of an error.

=cut

sub DelInvBookWfBaseItem {
    my $id = shift;

    (defined($id) && $id) || return();
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare('
        DELETE FROM invbook_writeoff_bases
        WHERE writeoff_basis_entry_id = ?
    ');
    return $sth->execute($id);
}


=head2 AddItemToInventory

    ( $result, $error ) = AddItemToInventory({
            itemnumber => $itemnumber,
            invbook_id => $invbook_definition_id,
            [ accession_id => $accession_id ]
            })
    Adds item to inventory book with KA variant. Which is adding only
    itemnumber, biblionumber, accession number and other numbers to inventory
    table. Data to fill are taken from items table, so item must be added to 
    items table before adding to inventory. 
    Doesn't fill columns with biblio data, this may be done later (after print?).
    Also can modify items in inventory. If provided itemnumber exists already
    in inventory and inventory number, is the same in inventory table and items table.

    If something went wrong, first value is undef, and next is error name:
    NO_DATA - function called with undef arg
    NO_ITEM - there's no item with given itemnumber in database
    NO_INV_BOOK_ID - inventory book id is not defined in data set
    IVB_ENTRY_ALREADY_EXISTS - given invenory number already exist in given inventory
        book.
    IVB_ENTRY_ADD_UNSUCCESSFULL - adding/modifying returns error.

=cut

sub AddItemToInventory {
    my ( $data ) = @_;

    return ( undef, "NO_DATA" ) unless defined $data;

    my $item = GetItem($data->{itemnumber});
    return ( undef, "NO_ITEM", $data->{itemnumber} ) unless defined $item;

    my $accession = _getAccessionNo($item->{itemnumber});
    my $accession_id = (defined @$accession) ? $accession->[0] : $data->{accession_id};
    my $user = C4::Context->userenv;

    return ( undef, "NO_INVBOOK_ID" ) unless $data->{invbook_id};
    my $invbook = GetInvBookDef($data->{invbook_id});
    my $prefix = $invbook->{number_prefix};
    my $suffix = $invbook->{number_suffix};

    ( my $number = $item->{stocknumber} ) =~ s/$prefix(\d*)$suffix/$1/;

    my $inventory_item = ({
            invbook_definition_id => $data->{invbook_id},
            inventory_number => $number,
            callnumber => $item->{itemcallnumber},
            unitprice => $item->{price},
            acquisition_mode => $item->{accq_type},
            biblionumber => $item->{biblionumber},
            itemnumber => $item->{itemnumber},
            publication_nr => $item->{enumchron},
            });
    $inventory_item->{accession_id} = $accession_id if defined $accession_id;

    #check if item is allready in inventory if so Modify instead od Add
    my $olditem = SearchInvBookItems({
            inventory_number => $inventory_item->{inventory_number},
            invbook_definition_id => $data->{invbook_id},
        });
    my $exists_itemnumber = SearchInvBookItems({
            itemnumber => $data->{itemnumber},
        });
    if ( !@$olditem && @$exists_itemnumber ) {    #itemnumber already in inv book, but this is not modification
        return (undef, "ITEM_ALREADY_IN_INV", $data->{itemnumber});#than means we try to add another inv item of that same item
    }

    my $result;
    if ( @$olditem ) {
        if ( $olditem->[0]->{itemnumber} == $item->{itemnumber} ) {
            $inventory_item->{modified_by} = $user->{number};
            $inventory_item->{invbook_item_id} = $olditem->[0]->{invbook_item_id};

            #TODO: Add log action modified from $olditem to $inventory_item

            $result = ModInvBookItem($inventory_item);
        } else {
            warn "Inventory number exist with different itemnumber";
            return(undef, "IVB_ENTRY_ALREADY_EXISTS", $number);
        }
    } else {
        my $today_date = sprintf('%04d-%02d-%02d', Today());
        $inventory_item->{date_added} = $today_date;
        $inventory_item->{created_by} = $user->{number};
        $result = AddInvBookItem($inventory_item);
    }
    defined($result) || return(undef, 'IVB_ENTRY_ADD_UNSUCCESSFULL');

    return ( $result );

}

sub _getAccessionNo {
    my $itemnumber = shift;

    my $dbh = C4::Context->dbh;
    my $acc_id = $dbh->selectcol_arrayref("SELECT ia.accession_id FROM aqorders_items ai
            JOIN aqorders ao ON ( ai.ordernumber = ao.ordernumber)
            JOIN invbook_accessions ia ON ( ao.invoiceid = ia.invoice_id )
                WHERE ai.itemnumber = ?", undef, $itemnumber);

    return $acc_id;
}

=head2 RefreshItemInInventory

    Modyfies items aleready in inventory. Requires only itemnumber param. 
    TODO: Should be using setting to determine which variant use to mod - KA or PK


=cut

sub RefreshItemInInventory {
    my $params = shift @_;

    my $invbook_item = SearchInvBookItems({ itemnumber => $params->{itemnumber} });

    #that's not error, most common situation when item was not attached to inventory
    return(1, 'INV_ITEM_NOT_FOUND') unless defined($invbook_item);
    die "TWO_OR_MORE_ITEMNUMBERS\n" if ( scalar(@$invbook_item) > 1);
    
    my ( $result, $error ) = AddItemToInventory( { itemnumber => $invbook_item->[0]->{itemnumber},
            invbook_id => $invbook_item->[0]->{invbook_definition_id} } );
    
    return( $result, $error);
}


=head2 AddItemToInventory_BPK_Book

    ($inv_item_id, $error_code) = AddItemToInventory_BPK_Book( {
         itemnumber => $itemnumber,
         check_possibility => 1
    } );

This function adds an item (creates an inventory entry) for the given
item record identified by 'itemnumber' parameter to the invbook_items table.
It's (kinda, sorta, rather) specific variant of adding an item to inventory;
in short:

- (destination) inventory book is determined by call number prefix

- inventory number may be generated as usual (i.e., "next available" - in
case when numbering_format in book definition is set to 'NEXT_AVAILABLE'),
or not (in that 2nd mode, instead, numeric part of call number would
be used as inventory_number field).

Return values:

1/ ($invbook_item_id): on success, ID of newly created invbook_items record is returned

2/ (undef, $error_code): in case of an error - possible error codes are:

    INCOMPLETE_ITEM_DATA
    UNRECOGNISED_CALLNR_FORMAT
    INVBOOK_DESTINATION_NOT_FOUND
    NON_UNIQUE_CNR_PREFIXES_IN_BOOKDEFS
    MISSING_ACQ_DATA
    MISSING_ACC_INVOICE_ASSOCIATION
    NUMBER_FORMAT_NOT_VALID
    IVB_ENTRY_ALREDAY_EXISTS
    IVB_ENTRY_ADD_UNSUCCESSFULL

3/ (undef, { invbook_name => .., accession_number => ..,
inv_item_number => .. , manual_numbering => .. }): if
'check_possibility' parameter is true, nothing is added to the
inventory; in that case, this function just tries to determine to which
inventory book this item would be added to (if it wasn't a "dry run"),
and in the process performing all checks to ensure the possiblity
of adding this an item to the inventory.

=cut

sub AddItemToInventory_BPK_Book {
    my $params = shift;

    ($params && $params->{itemnumber}) || return(undef, 'INCOMPLETE_ITEM_DATA');
    my $itemnumber = $params->{itemnumber};
    my $item = GetItem($itemnumber);

    ($item && $item->{itemnumber}) || return(undef, 'INCOMPLETE_ITEM_DATA');
    my $bibliodata = GetBiblioData($item->{biblionumber});
    ($bibliodata && $bibliodata->{biblionumber}) || return(undef, 'INCOMPLETE_ITEM_DATA');

    my $callnumber = $item->{itemcallnumber} // '';
    my ($cn_prefix, $cn_number);
    ( (($cn_prefix, $cn_number) = ($callnumber=~/^([A-Za-z\-\.]{2,})(\d.*)$/)) == 2 && $cn_number ne '0' )
      || return(undef, 'UNRECOGNISED_CALLNR_FORMAT');

    $cn_prefix =~ s/\..*$/\./;
    $cn_prefix =~ /^[A-Za-z]+[\-\.]$/ || return(undef, 'UNRECOGNISED_CALLNR_FORMAT');

    my $ibdl = SearchInvBookDefs( { 'type' => 'I' } );
    $ibdl || return(undef, 'INVBOOK_DESTINATION_NOT_FOUND');

    my $bdcn = {};
    for my $bh (@$ibdl) {
        (defined($bh->{cn_prefix}) && $bh->{cn_prefix} ne '') || next;
        $bdcn->{$bh->{cn_prefix}} ||= [];
        push(@{$bdcn->{$bh->{cn_prefix}}}, $bh);
    }

    defined($bdcn->{$cn_prefix}) || return(undef, 'INVBOOK_DESTINATION_NOT_FOUND');
    @{$bdcn->{$cn_prefix}} == 1 || return(undef, 'NON_UNIQUE_CNR_PREFIXES_IN_BOOKDEFS');
    my $ibookdef = $bdcn->{$cn_prefix}->[0];
    my $manual_numbering = ($ibookdef->{numbering_format} && $ibookdef->{numbering_format} eq 'NEXT_AVAILABLE')? 0: 1;

    my $order = GetOrderFromItemnumber($item->{itemnumber});
    ($order && $order->{ordernumber} && $order->{basketno} && $order->{invoiceid})
      || return(undef, 'MISSING_ACQ_DATA');
    ($order->{'sort1'} && $order->{'sort2'})
      || return(undef, 'MISSING_ACQ_DATA');

    my $unitprice = $order->{unitprice} // 0;
    my $invoice = GetInvoice($order->{invoiceid});
    ($invoice && $invoice->{invoiceid}) || return(undef, 'MISSING_ACQ_DATA');

    my $accessions = SearchInvBookAccessions({
        invoice_id => $invoice->{invoiceid}
    });
    ($accessions && @$accessions == 1) || return(undef, 'MISSING_ACC_INVOICE_ASSOCIATION');
    my $accession = $accessions->[0];

    unless ($manual_numbering) {
        $cn_number = '';
        my ($next_number) = GetNextInventoryNumber($ibookdef->{invbook_definition_id});
        ($next_number && @$next_number == 1) || last;
        $cn_number = $next_number->[0];
    }
    $cn_number =~ /^[1-9]\d*$/ || return(undef, 'NUMBER_FORMAT_NOT_VALID');

    my $ex_item = SearchInvBookItems( {
        invbook_definition_id => $ibookdef->{invbook_definition_id},
        inventory_number => $cn_number,
    } );
    $ex_item && @$ex_item && return(undef, 'IVB_ENTRY_ALREDAY_EXISTS');

    $params->{check_possibility} && return(undef, {
        invbook_name =>  $ibookdef->{name},
        accession_number => $accession->{accession_number},
        inv_item_number => $cn_number,
        manual_numbering => $manual_numbering,
    });

    my $user = C4::Context->userenv;
    my $today_date = sprintf('%04d-%02d-%02d', Today());

    ## TODO: pretty-formated biblio data from MARC 245, 260, .. (???)
    ## TODO: st_class_1, st_class_2 (from order additional fields), def. location (from bookdef ?)
    my $inventory_item = {
        invbook_definition_id => $ibookdef->{invbook_definition_id},
        inventory_number => $cn_number,
        itemnumber => $item->{itemnumber},
        callnumber => $item->{itemcallnumber},

        biblionumber => $item->{biblionumber},
        title => $bibliodata->{title},
        author => $bibliodata->{author},
        publication_place => $bibliodata->{place},
        publication_date => $bibliodata->{copyrightdate},
        publication_nr => $bibliodata->{editionstatement},

        accession_id => $accession->{accession_id},
        acquisition_mode => $accession->{acquisition_mode},

        'st_class_1' => $order->{'sort1'},
        'st_class_2' => $order->{'sort2'},

        unitprice => $unitprice,
        date_added => $today_date,
        created_by => $user->{number},
        modified_by => $user->{number},
    };

    defined($item->{location}) && $item->{location} ne '' && do {
        $inventory_item->{location} = $item->{location};
    };
    defined($item->{itemnotes}) && $item->{itemnotes} ne '' && do {
        $inventory_item->{notes} = $item->{itemnotes};
    };

    ## FIXME: more robust error checking & reporting
    my $result = AddInvBookItem($inventory_item);
    defined($result) || return(undef, 'IVB_ENTRY_ADD_UNSUCCESSFULL');

    my $item_changes = { stocknumber => $cn_number };
    ModItem($item_changes, $item->{biblionumber}, $item->{itemnumber});

    return($result);
}

=head2 WriteoffItem

    ($woff_baseItem, $errors ) = WriteoffItem({
            writeoff_id => $woff_id,
            invbook_item_id => $invbook_item_id,
            action => $action,
            })
Function to add and modify writeoff items. This function should provide all necesary
changes when adding/modifying/deleting items in writeoff.

=cut

sub WriteoffItem {
    my ( $params ) = shift;

    my $writeoff_data;
    my @errors;
    my $user = C4::Context->userenv;

    my @required_fld = qw( writeoff_id invbook_item_id action );

    foreach ( @required_fld ) {
        unless ( defined $params->{$_} && $params->{$_} ){
            push @errors, "Required field not present $_";
        }
    }
    return ('', @errors) if scalar @errors;

    my $item_data = GetInvBookItemByID($params->{invbook_item_id});
    my $woff = GetInvBookWriteoff($params->{writeoff_id});

    map { $writeoff_data->{$_} = $params->{$_} } ( keys %$params );

    my $writeoff_basis_entry_id;
    if ( $params->{action} eq "add" ) {
        return ('', "No writeoff info") unless $woff;
        $writeoff_data->{invbook_definition_id} = $woff->{invbook_definition_id};
        $writeoff_data->{date_added} = $woff->{date_writeoff};
        $writeoff_data->{created_by} = $user->{number};
        $writeoff_basis_entry_id = AddInvBookWfBaseItem($writeoff_data);
        return ('', "Database error: Not modified") unless $writeoff_basis_entry_id;

    } elsif ( $params->{action} eq "delete" ) {
        return ('', "No item info") unless defined $item_data;
        DelInvBookWfBaseItem( $item_data->{writeoff_basis_entry_id} );
        $writeoff_data->{writeoff_id} = undef;
        $writeoff_basis_entry_id = undef;
    }

    ModInvBookItem({
            invbook_item_id => $writeoff_data->{invbook_item_id},
            writeoff_id => $writeoff_data->{writeoff_id},
            writeoff_basis_entry_id => $writeoff_basis_entry_id,
            });
    $writeoff_basis_entry_id = 1 if $params->{action} eq "delete";
    return $writeoff_basis_entry_id;
}

sub CloseWriteOffBasis {
    my $writeoff_id = shift @_;

    my $book_variant = C4::Context->preference("InventoryBookVariant") // '';
    {
        $book_variant eq 'BPK' || last;
        my $woff = GetInvBookWriteoff($writeoff_id);
        ($woff && $woff->{count_managed_manually}) || last;

        my ($nseq, $errtxt) = _genCloseManualWoffBasis_BPK($woff);
        defined($nseq) || warn($errtxt);
        return;
    }

    my $date = sprintf('%04d-%02d-%02d', Today());
    my $user = C4::Context->userenv;
    my $writeoff_items = SearchInvBookWfBaseItems({ writeoff_id => $writeoff_id });
    my $seq_number = _getLastWoffSeqNumber($writeoff_items->[0]->{invbook_definition_id});

    my @item_numbers;
    foreach my $item ( @{$writeoff_items} ) {
        my $item_info = GetInvBookItemByID($item->{invbook_item_id});

        #TODO: Add modify log action.
        $seq_number++;
        ModInvBookWfBaseItem({
                writeoff_basis_entry_id => $item->{writeoff_basis_entry_id},
                seq_number => $seq_number,
                date_added => $date,
                modified_by => $user->{number},
                });
        push @item_numbers, $item_info->{itemnumber};
    }
    _modWriteoffItems_KA({
            itemnumbers => \@item_numbers,
            writeoff_id => $writeoff_id,
    }) unless ($book_variant eq 'BPK');
    ModInvBookWriteoff({
            writeoff_id => $writeoff_id,
            current_status => "CL",
            });
}

sub _getLastWoffSeqNumber {
    my $writeoff_def_id = shift @_;

    my $dbh = C4::Context->dbh;
    my $last_seq = $dbh->selectcol_arrayref("SELECT MAX(seq_number) FROM invbook_writeoff_bases
            WHERE invbook_definition_id =?", undef, $writeoff_def_id);
    return $last_seq->[0] if defined $last_seq->[0];

    $last_seq = $dbh->selectcol_arrayref("SELECT writeoff_basis_seq_number_last FROM invbook_definitions
            WHERE invbook_definition_id = ?", undef, $writeoff_def_id);
    $last_seq->[0] = $last_seq->[0] // 1;
    return $last_seq->[0];

}

sub _modWriteoffItems_KA {
    my $params = shift @_;

    my $writeoff_info = GetInvBookWriteoff( $params->{writeoff_id} );

    my $item_col; my $item_val;
    for ($writeoff_info->{reason}) {
        when (/^OTH/) { $item_col = "withdrawn"; $item_val = 4; } #Other
        when (/^WTH/) { $item_col = "withdrawn"; $item_val = 1; } #Withdrawn
        when (/^NRET/) { $item_col = "itemlost";  $item_val = 3; } #Lost and returned
        when (/^LST/) { $item_col = "itemlost";  $item_val = 1; } #Lost
        when (/^DMG/) { $item_col = "damaged";   $item_val = 1; } #Damaged
        default  { $item_col = "withdrawn";      $item_val = 5; } #Undefined
    }
    my $item_changes = {
        $item_col => $item_val,
        itemcallnumber =>$writeoff_info->{base_document_number},
    };

    foreach my $itemnumber ( @{$params->{itemnumbers}} ) {
        ModItem($item_changes, undef, $itemnumber);
    }

}

sub _genCloseManualWoffBasis_BPK {
    my $woff = shift;

    $woff->{current_status} && ($woff->{current_status} eq 'CL' || $woff->{current_status} eq 'PR')
      && return(undef, 'Writeoff already closed');
    $woff->{count_managed_manually} || return(undef, 'Not manually managed');
    my $unit_count = $woff->{unit_count} || 0;
    my $writeoff_items = SearchInvBookWfBaseItems({ writeoff_id => $woff->{writeoff_id} });
    $writeoff_items && scalar(@$writeoff_items) && return(undef, 'Writeoff has entries already added');

    my $seq_number = _getLastWoffSeqNumber($woff->{invbook_definition_id});
    my $user = C4::Context->userenv;
    my $tddate = sprintf('%04d-%02d-%02d', Today());

    for (my $i = 0; $i < $unit_count; $i++) {
        $seq_number++;
        my $entry_data = {
            invbook_definition_id => $woff->{invbook_definition_id},
            writeoff_id => $woff->{writeoff_id},
            invbook_item_id => undef,
            seq_number => $seq_number,
            date_added => $tddate,
            created_by => $user->{number},
            modified_by => $user->{number},
        };
        my $woff_basis_entry_id = AddInvBookWfBaseItem($entry_data);
        return (undef, "Database error: Not added") unless $woff_basis_entry_id;
    }

    ModInvBookWriteoff({ writeoff_id => $woff->{writeoff_id}, current_status => "CL" });
    return($seq_number);
}


=head1 TODO

1) Update total_items total_cost entry_number_last in invbook_definitions
when adding/modifying/deleting items

2) Re: note #1: looks like updating those numerous "total" item count /
cost / last number used / .. values we have in database schema would
require _a lot_ of effort (even with mysql transactions/table locking
etc. involved, it will be pretty hard to implement it in such a way that
ensures such things are always kept in sync, and so on). Also (just IMO),
it's not awfully clear that such approach[es] would be all that much
beneficial after all.. Maybe we should just ditch it completely
and/or disregard it with as much dignity as possible ;).

=cut

END { }

1;

__END__
