<script type="text/javascript">
//<![CDATA[
//]]>
</script>
<div id="toolbar" class="btn-toolbar">
    <form id="accession_toolbar" name="accession_toolbar" action="/cgi-bin/koha/inventory/accession_manage.pl" method="get">
            <div class="btn-group"><button name="op" value="add" id="acc_toolbar_button_add" class="btn btn-small" type="submit"><i class="icon-plus"></i> Add accession</button></div>
            <div class="btn-group"><button name="op" value="edit" id="acc_toolbar_button_edit" class="btn btn-small" type="submit" disabled><i class="icon-edit"></i> Modify accession</button></div>
            <div class="btn-group"><button name="op" value="delete" id="acc_toolbar_button_delete" class="btn btn-small" type="submit" disabled><i class="icon-minus"></i> Delete accession</button></div>
        <input name="acc_id" id="acc_id" type="hidden" value="" />
        <input name="inv_book" id="inv_book" type="hidden" value="[% inv_book %]" />
    </form>
</div>
