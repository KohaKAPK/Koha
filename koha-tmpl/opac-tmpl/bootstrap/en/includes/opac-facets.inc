[% IF ( opacfacets && facets_loop && total ) %]
    <div id="search-facets">
        <h4><a href="#" class="menu-collapse-toggle">Refine your search</a></h4>
        <ul class="menu-collapse">
            <li id="availability_facet">Availability
                <ul>
                    <li>
                        [% IF ( available ) %]
                            Showing only <strong>available</strong> items. <a href="/cgi-bin/koha/opac-search.pl?[% query_cgi %][% limit_cgi_not_availablity %][% IF ( sort_by ) %]&amp;sort_by=[% sort_by |url %][% END %]">Show all items</a>
                        [% ELSE %]
                            <a href="/cgi-bin/koha/opac-search.pl?[% query_cgi %][% limit_cgi |url %][% IF ( sort_by ) %]&amp;sort_by=[% sort_by |url %][% END %]&amp;limit=available">Limit to currently available items.</a>
                        [% END %]
                    </li>
                </ul>
                [% IF ( related ) %] <li>(related searches: [% FOREACH relate IN related %][% relate.related_search %][% END %])</li>[% END %]
            </li>

            [% FOREACH facets_loo IN facets_loop %]
                [% IF facets_loo.facets.size > 0 %]
                    <li id="[% facets_loo.type_id %]">
                        [% IF facets_loo.type_label_Authors %]<h5 id="facet-authors">Authors</h5>[% END %]
                        [% IF facets_loo.type_label_Titles %]<h5 id="facet-titles">Titles</h5>[% END %]
                        [% IF facets_loo.type_label_Topics %]<h5 id="facet-topics">Topics</h5>[% END %]
                        [% IF facets_loo.type_label_Places %]<h5 id="facet-places">Places</h5>[% END %]
                        [% IF facets_loo.type_label_Series %]<h5 id="facet-series">Series</h5>[% END %]
                        [% IF facets_loo.type_label_ItemTypes %]<h5 id="facet-itemtypes">Item types</h5>[% END %]
                        [% UNLESS singleBranchMode %]
                            [% IF ( facets_loo.type_label_HomeLibrary ) %]<span id="facet-home-libraries">Home libraries</span>[% END %]
                            [% IF ( facets_loo.type_label_HoldingLibrary ) %]<span id="facet-holding-libraries">Holding libraries</span>[% END %]
                        [% END %]
                        [% IF facets_loo.type_label_Location %]<h5 id="facet-locations">Locations</h5>[% END %]
                        <ul>
                            [% FOREACH facet IN facets_loo.facets %]
                                <li>
                                  [% SET query_cgi_f = query_cgi %]
                                  [% SET limit_cgi_f = limit_cgi | url %]
                                  [% SET url = "/cgi-bin/koha/opac-search.pl?" _ query_cgi_f _ limit_cgi_f %]
                                  [% IF ( sort_by ) %]
                                    [% SET url = url _ "&amp;sort_by=" _ sort_by |url %]
                                  [% END %]
                                  [% facet.facet_link_value = BLOCK %][% facet.facet_link_value | uri %][% END %]
                                  [% IF facet.active %]
                                    [% SET url = url _ "&amp;nolimit=" _ facet.type_link_value _ ":" _ facet.facet_link_value %]
                                    <span class="facet-label">[% facet.facet_label_value %]</span>
                                    [<a href="[% url |url%]" title="Remove facet [% facet.facet_link_value | html %]">x</a>]
                                  [% ELSE %]
                                    [% SET url = url _ "&amp;limit=" _ facet.type_link_value _ ":" _ facet.facet_link_value %]
                                    <span class="facet-label"><a href="[% url |url%]" title="[% facet.facet_title_value |html %]">[% facet.facet_label_value %]</a></span>
                                    [% IF ( displayFacetCount ) %]
                                      <span class="facet-count"> ([% facet.facet_count %])</span>
                                    [% END %]
                                  [% END %]
                                </li>
                            [% END %]
                            [% IF ( facets_loo.expandable ) %]
                                <li class="showmore">
                                    <a href="/cgi-bin/koha/opac-search.pl?[% query_cgi %][% limit_cgi |url %][% IF ( sort_by ) %]&amp;sort_by=[% sort_by |url %][% END %][% IF ( offset ) %]
                                            &amp;offset=[% offset |url %][% END %]&amp;expand=[% facets_loo.expand |url %]#[% facets_loo.type_id |url %]">Show more</a>
                                </li>
                            [% END %]
                        </ul>
                    </li>
                [% END # / IF facets_loo.facets.size > 0 %]
            [% END # / FOREACH facets_loo  %]
        </ul>
    </div>  <!-- / #search-facets -->

    [% IF ( OPACResultsSidebar ) %]
        <div id="opacresultssidebar">
            [% OPACResultsSidebar %]
        </div>
    [% END %]
[% END # / IF opacfacets && facets_loop %]
