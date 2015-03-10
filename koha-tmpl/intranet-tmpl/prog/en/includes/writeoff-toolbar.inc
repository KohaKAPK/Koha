<script type="text/javascript">
//<![CDATA[
//]]>
</script>
<div id="toolbar" class="btn-toolbar">
    <form id="accession_toolbar" name="accession_toolbar" action="/cgi-bin/koha/inventory/writeoff_manage.pl" method="get">
    p
            <div class="btn-group"><button name="op" value="add" class="btn btn-small" type="submit"><i class="icon-plus"></i>Utwórz nowy protokół ubytków</button></div>
            <div class="btn-group"><button name="op" value="edit" class="btn btn-small" type="submit"><i class="icon-edit"></i>Modyfikuj protokół</button></div>
<!--            <div class="btn-group"><button name="op" value="delete" class="btn btn-small" type="submit"><i class="icon-minus"></i>Usuń (?)</button></div> -->
        <input name="woff_id" id="woff_id" type="hidden" value="" />
        <input name="inv_book" id="inv_book" type="hidden" value="[% inv_book %]" />
    </form>
</div>
