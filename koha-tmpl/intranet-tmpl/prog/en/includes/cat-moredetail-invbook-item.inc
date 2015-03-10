            <div class="listgroup"><h4>Inwentarz</h4>
            <ol class="bibliodetails">
            [% IF ITEM_DAT.invbookitem.invbook_item_id %]
                <li><span class="label">Numer inwentarza:</span>
                    <a href="/cgi-bin/koha/inventory/item_view.pl?item_id=[% ITEM_DAT.invbookitem.invbook_item_id %]">[% ITEM_DAT.invbookitem.inventory_number %]</a>
                </li>
                <li><span class="label">Księga inwentarzowa:</span>
                    [% ITEM_DAT.invbookitem.bookdef.name |html %]
                </li>
                [% IF ITEM_DAT.invbookitem.accession.accession_id %]
                <li><span class="label">Numer akcesji:</span>
                    <a href="/cgi-bin/koha/inventory/accession_view.pl?acc_id=[% ITEM_DAT.invbookitem.accession.accession_id %]">
                    [% ITEM_DAT.invbookitem.accession.accession_number %]</a>
                </li>
                [% END %]
                [% IF ( ITEM_DAT.invbookitem.writeoff_id && ITEM_DAT.invbookitem.writeoff.writeoff_id ) %]
                <li><span class="label">Ubytkowane dnia:</span>
                    [% ITEM_DAT.invbookitem.writeoff.date_writeoff | $KohaDates %]
                </li>
                <li><span class="label">Numer rejestru:</span>
                    <a href="/cgi-bin/koha/inventory/writeoff_view.pl?showtab=entry_details&amp;woff_id=[% ITEM_DAT.invbookitem.writeoff.writeoff_id %]">
                    [% ITEM_DAT.invbookitem.writeoff.writeoff_number %]</a>
                </li>
                <li><span class="label">Numer protokołu:</span>
                [% IF ( ITEM_DAT.invbookitem.writeoff.base_document_number ) %]
                    <a href="/cgi-bin/koha/inventory/writeoff_view.pl?showtab=basedoc_details&amp;woff_id=[% ITEM_DAT.invbookitem.writeoff.writeoff_id %]">
                    [% ITEM_DAT.invbookitem.writeoff.base_document_number |html %]</a>
                [% ELSE %]
                    brak danych
                [% END %]
                </li>
                <li><span class="label">Księga ubytków:</span>
                    [% ITEM_DAT.invbookitem.wbookdef.name |html %]
                </li>
                [% END %]
            [% ELSE %]
                <li><span class="label">Numer inwentarza:</span>
                    Brak wpisu
                </li>

                [% IF ( Koha.Preference('InventoryBookVariant') == 'BPK' ) %]
                    [% IF ITEM_DAT.invbookcheckp.not_ok %]
                    <li><span class="label">Status:</span>
                        <b>Brak możliwości dodania do inwentarza</b>
                    </li>
                    <li><span class="label">Powód:</span>
                        [% IF ( ITEM_DAT.invbookcheckp.not_ok == 'INCOMPLETE_ITEM_DATA' ) %]
                            Błędne lub niekompletne dane w rekordzie egzemplarza
                        [% ELSIF ( ITEM_DAT.invbookcheckp.not_ok == 'UNRECOGNISED_CALLNR_FORMAT' ) %]
                            Nieobsługiwana postać lub błędny format sygnatury
                        [% ELSIF ( ITEM_DAT.invbookcheckp.not_ok == 'INVBOOK_DESTINATION_NOT_FOUND' ) %]
                            Brak księgi z takim prefiksem sygnatury
                        [% ELSIF ( ITEM_DAT.invbookcheckp.not_ok == 'NON_UNIQUE_CNR_PREFIXES_IN_BOOKDEFS' ) %]
                            Niejednoznaczne ustawienia prefiksów w definicjach ksiąg
                        [% ELSIF ( ITEM_DAT.invbookcheckp.not_ok == 'MISSING_ACQ_DATA' ) %]
                            Brak danych w module gromadzenia dotyczących tej pozycji
                        [% ELSIF ( ITEM_DAT.invbookcheckp.not_ok == 'MISSING_ACC_INVOICE_ASSOCIATION' ) %]
                            Brak skojarzenia rekordu faktury z rekordem akcesji
                        [% ELSIF ( ITEM_DAT.invbookcheckp.not_ok == 'NUMBER_FORMAT_NOT_VALID' ) %]
                            Błąd numeracji lub niepoprawny format sygnatury
                        [% ELSIF ( ITEM_DAT.invbookcheckp.not_ok == 'IVB_ENTRY_ALREDAY_EXISTS' ) %]
                            Istnieje już w inwentarzu wpis dla pozycji o takim numerze
                        [% ELSE %]
                            [% ITEM_DAT.invbookcheckp.not_ok %]
                        [% END %]
                    </li>
                    [% ELSE %]
                    <li><span class="label">Status:</span>
                        <b>Można dodać</b>
                    </li>
                    <li><span class="label">Księga (docelowo):</span>
                        [% ITEM_DAT.invbookcheckp.add_ok.invbook_name |html %]
                    </li>
                    <li><span class="label">Nr akcesji (docelowo):</span>
                        [% ITEM_DAT.invbookcheckp.add_ok.accession_number |html %]
                    </li>
                    [% UNLESS ( ITEM_DAT.invbookcheckp.add_ok.manual_numbering ) %]
                    <li><span class="label">Numeracja:</span>
                        automatyczna (kolejny wolny numer: [% ITEM_DAT.invbookcheckp.add_ok.inv_item_number %])
                    </li>
                    [% END %]
                    <li><span class="label">Akcja:</span>
                        <form action="updateitem.pl" method="post">
                        <input type="hidden" name="biblionumber" value="[% ITEM_DAT.biblionumber %]" />
                        <input type="hidden" name="biblioitemnumber" value="[% ITEM_DAT.biblioitemnumber %]" />
                        <input type="hidden" name="itemnumber" value="[% ITEM_DAT.itemnumber %]" />
                        <input type="hidden" name="invbook_action_add" value="1" />
                        <input type="submit" name="submit" class="submit" value="Dodaj do inwentarza" />
                        </form>
                    </li>
                    [% END %]
                [% END %]
            [% END %]

            </ol>
            </div>
