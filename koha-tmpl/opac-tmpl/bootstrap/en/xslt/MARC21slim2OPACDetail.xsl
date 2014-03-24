<?xml version="1.0" encoding="UTF-8"?>
<!-- $Id: MARC21slim2DC.xsl,v 1.1 2003/01/06 08:20:27 adam Exp $ -->
<!DOCTYPE stylesheet [<!ENTITY nbsp "&#160;" >]>
<xsl:stylesheet version="1.0"
  xmlns:marc="http://www.loc.gov/MARC21/slim"
  xmlns:items="http://www.koha-community.org/items"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  exclude-result-prefixes="marc items">
    <xsl:import href="MARC21slimUtils.xsl"/>
    <xsl:output method = "html" indent="yes" omit-xml-declaration = "yes" encoding="UTF-8"/>
    <xsl:template match="/">
            <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="marc:record">

        <!-- Option: Display Alternate Graphic Representation (MARC 880)  -->
        <xsl:variable name="display880" select="boolean(marc:datafield[@tag=880])"/>

    <xsl:variable name="UseControlNumber" select="marc:sysprefs/marc:syspref[@name='UseControlNumber']"/>
    <xsl:variable name="DisplayOPACiconsXSLT" select="marc:sysprefs/marc:syspref[@name='DisplayOPACiconsXSLT']"/>
    <xsl:variable name="OPACURLOpenInNewWindow" select="marc:sysprefs/marc:syspref[@name='OPACURLOpenInNewWindow']"/>
    <xsl:variable name="URLLinkText" select="marc:sysprefs/marc:syspref[@name='URLLinkText']"/>

    <xsl:variable name="SubjectModifier"><xsl:if test="marc:sysprefs/marc:syspref[@name='TraceCompleteSubfields']='1'">,complete-subfield</xsl:if></xsl:variable>
    <xsl:variable name="UseAuthoritiesForTracings" select="marc:sysprefs/marc:syspref[@name='UseAuthoritiesForTracings']"/>
    <xsl:variable name="TraceSubjectSubdivisions" select="marc:sysprefs/marc:syspref[@name='TraceSubjectSubdivisions']"/>
    <xsl:variable name="Show856uAsImage" select="marc:sysprefs/marc:syspref[@name='OPACDisplay856uAsImage']"/>
    <xsl:variable name="OPACTrackClicks" select="marc:sysprefs/marc:syspref[@name='TrackClicks']"/>
    <xsl:variable name="theme" select="marc:sysprefs/marc:syspref[@name='opacthemes']"/>
    <xsl:variable name="biblionumber" select="marc:datafield[@tag=999]/marc:subfield[@code='c']"/>
    <xsl:variable name="TracingQuotesLeft">
      <xsl:choose>
        <xsl:when test="marc:sysprefs/marc:syspref[@name='UseICU']='1'">{</xsl:when>
        <xsl:otherwise>"</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="TracingQuotesRight">
      <xsl:choose>
        <xsl:when test="marc:sysprefs/marc:syspref[@name='UseICU']='1'">}</xsl:when>
        <xsl:otherwise>"</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
        <xsl:variable name="leader" select="marc:leader"/>
        <xsl:variable name="leader6" select="substring($leader,7,1)"/>
        <xsl:variable name="leader7" select="substring($leader,8,1)"/>
        <xsl:variable name="leader19" select="substring($leader,20,1)"/>
        <xsl:variable name="controlField008" select="marc:controlfield[@tag=008]"/>
        <xsl:variable name="itemtype" select="marc:datafield[@tag=942]/marc:subfield[@code='c']"/>
        <xsl:variable name="materialTypeCode">
            <xsl:choose>
                <xsl:when test="$itemtype='BK'">BK</xsl:when>
                <xsl:when test="$itemtype='CF'">MU</xsl:when>
                <xsl:when test="$itemtype='CR'">SE</xsl:when>
                <xsl:when test="$itemtype='MP'">PR</xsl:when>
                <xsl:when test="$leader19='a'">ST</xsl:when>
                <xsl:when test="$leader6='a'">
                    <xsl:choose>
                        <xsl:when test="$leader7='c' or $leader7='d' or $leader7='m'">BK</xsl:when>
                        <xsl:when test="$leader7='i' or $leader7='s'">SE</xsl:when>
                        <xsl:when test="$leader7='a' or $leader7='b'">AR</xsl:when>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="$leader6='t'">BK</xsl:when>
                <xsl:when test="$leader6='o' or $leader6='p'">MX</xsl:when>
                <xsl:when test="$leader6='m'">CF</xsl:when>
                <xsl:when test="$leader6='e' or $leader6='f'">MP</xsl:when>
                <xsl:when test="$leader6='g' or $leader6='k' or $leader6='r'">VM</xsl:when>
                <xsl:when test="$leader6='i' or $leader6='j'">MU</xsl:when>
                <xsl:when test="$leader6='c' or $leader6='d'">PR</xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="materialTypeLabel">
            <xsl:choose>
                <xsl:when test="$leader19='a'">Set</xsl:when>
                <xsl:when test="$leader6='a'">
                    <xsl:choose>
                        <xsl:when test="$leader7='c' or $leader7='d' or $leader7='m'">Book</xsl:when>
                        <xsl:when test="$leader7='i' or $leader7='s'">
                            <xsl:choose>
                                <xsl:when test="substring($controlField008,22,1)!='m'">Continuing Resource</xsl:when>
                                <xsl:otherwise>Series</xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when test="$leader7='a' or $leader7='b'">Article</xsl:when>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="$leader6='t'">Book</xsl:when>
				<xsl:when test="$leader6='o'">Kit</xsl:when>
                <xsl:when test="$leader6='p'">Mixed Materials</xsl:when>
                <xsl:when test="$leader6='m'">Computer File</xsl:when>
                <xsl:when test="$leader6='e' or $leader6='f'">Map</xsl:when>
                <xsl:when test="$leader6='g' or $leader6='k' or $leader6='r'">Visual Material</xsl:when>
                <xsl:when test="$leader6='j'">Music</xsl:when>
                <xsl:when test="$leader6='i'">Sound</xsl:when>
                <xsl:when test="$leader6='c' or $leader6='d'">Score</xsl:when>
            </xsl:choose>
        </xsl:variable>

        <!-- Title Statement -->
        <!-- Alternate Graphic Representation (MARC 880) -->
        <xsl:if test="$display880">
            <h1 class="title">
                <xsl:call-template name="m880Select">
                    <xsl:with-param name="basetags">245</xsl:with-param>
                    <xsl:with-param name="codes">abhfgknps</xsl:with-param>
                </xsl:call-template>
            </h1>
        </xsl:if>
        <table id="MARCbiblio">

        <xsl:choose>
            <xsl:when test="marc:datafield[@tag=100] or marc:datafield[@tag=110] or marc:datafield[@tag=111]">
                <tr class="author"><td class="labelColumn">Author: </td><td class="biblioAuthor">
                    <xsl:call-template name="showAuthor">
                        <xsl:with-param name="authorfield" select="marc:datafield[@tag=100 or @tag=110 or @tag=111]"/>
                        <xsl:with-param name="UseAuthoritiesForTracings" select="$UseAuthoritiesForTracings"/>
                    </xsl:call-template>
                </td>
                </tr>
            </xsl:when>
        </xsl:choose>

        <xsl:if test="marc:datafield[@tag=245]">
        <tr class="title"><td class="labelColumn">Title: </td><td class="biblioTitle">
            <xsl:for-each select="marc:datafield[@tag=245]">
                <xsl:call-template name="fieldSelect" />
            </xsl:for-each>
<!--
            <xsl:for-each select="marc:datafield[@tag=245]">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">a</xsl:with-param>
                    </xsl:call-template>
                    <xsl:if test="marc:subfield[@code='h']">
                        <xsl:text> </xsl:text>
                        <xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">h</xsl:with-param>
                        </xsl:call-template>
                    </xsl:if>
                    <xsl:if test="marc:subfield[@code='b']">
                        <xsl:text> </xsl:text>
                        <xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">b</xsl:with-param>
                        </xsl:call-template>
                    </xsl:if>
                    <xsl:if test="marc:subfield[@code='c']">
                        <xsl:text> </xsl:text>
                        <xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">c</xsl:with-param>
                        </xsl:call-template>
                    </xsl:if>
                <xsl:text> </xsl:text>
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">fgknps</xsl:with-param>
                    </xsl:call-template>
            </xsl:for-each>  -->
        </td>
        </tr>
        </xsl:if>

        <!-- Author Statement: Alternate Graphic Representation (MARC 880) -->
<!--        <xsl:if test="$display880">
            <h5 class="author">
                <xsl:call-template name="m880Select">
                    <xsl:with-param name="basetags">100,110,111,700,710,711</xsl:with-param>
                    <xsl:with-param name="codes">abc</xsl:with-param>
                    <xsl:with-param name="index">au</xsl:with-param>
-->
                    <!-- do not use label 'by ' here, it would be repeated for every occurence of 100,110,111,700,710,711 -->
<!--                </xsl:call-template>
            </h5>
        </xsl:if>
        <xsl:if test="$leader7!='s'">
        <xsl:choose>
            <xsl:when test="marc:datafield[@tag=100] or marc:datafield[@tag=110] or marc:datafield[@tag=111] or marc:datafield[@tag=700] or marc:datafield[@tag=710] or marc:datafield[@tag=711]">
                <tr class="author"><td class="labelColumn">Author</td><td class="biblioAuthor">
                    <xsl:call-template name="showAuthor">
                        <xsl:with-param name="authorfield" select="marc:datafield[@tag=100 or @tag=110 or @tag=111 or @tag=700 or @tag=710 or @tag=711]"/>
                        <xsl:with-param name="UseAuthoritiesForTracings" select="$UseAuthoritiesForTracings"/>
                        <xsl:with-param name="materialTypeLabel" select="$materialTypeLabel"/>
                        <xsl:with-param name="theme" select="$theme"/>
                    </xsl:call-template>
                </td>
                </tr>
            </xsl:when>
        </xsl:choose>
        </xsl:if>
-->
   <xsl:if test="$DisplayOPACiconsXSLT!='0'">
        <xsl:if test="$materialTypeCode!=''">
        <span class="type"><span class="label">Type: </span>
        <xsl:element name="img"><xsl:attribute name="src">/opac-tmpl/lib/famfamfam/<xsl:value-of select="$materialTypeCode"/>.png</xsl:attribute><xsl:attribute name="alt">materialTypeLabel</xsl:attribute><xsl:attribute name="class">materialtype</xsl:attribute></xsl:element>
        <xsl:value-of select="$materialTypeLabel"/>
        </span>
        </xsl:if>
   </xsl:if>

        <!--Series: Alternate Graphic Representation (MARC 880) -->
        <xsl:if test="$display880">
            <xsl:call-template name="m880Select">
                <xsl:with-param name="basetags">440,490</xsl:with-param>
                <xsl:with-param name="codes">av</xsl:with-param>
                <xsl:with-param name="class">results_summary series</xsl:with-param>
                <xsl:with-param name="label">Series: </xsl:with-param>
                <xsl:with-param name="index">se</xsl:with-param>
            </xsl:call-template>
        </xsl:if>

        <!-- Series -->
        <xsl:if test="marc:datafield[@tag=440 or @tag=490]">
        <tr class="series"><td class="labelColumn">Series: </td>
        <!-- 440 -->
        <td class="biblioDetail">
        <xsl:for-each select="marc:datafield[@tag=440]">
            <a><xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=se,phr:"<xsl:value-of select="marc:subfield[@code='a']"/>"</xsl:attribute>
            <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">av</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
            </a>
            <xsl:call-template name="part"/>
            <xsl:choose><xsl:when test="position()=last()"><xsl:text>. </xsl:text></xsl:when><xsl:otherwise><xsl:text> ; </xsl:text></xsl:otherwise></xsl:choose>
        </xsl:for-each>

        <!-- 490 Series not traced, Ind1 = 0 -->
        <xsl:for-each select="marc:datafield[@tag=490][@ind1!=1]">
            <a><xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=se,phr:"<xsl:value-of select="marc:subfield[@code='a']"/>"</xsl:attribute>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">av</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
            </a>
                    <xsl:call-template name="part"/>
        <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
        </xsl:for-each>
        <!-- 490 Series traced, Ind1 = 1 -->
        <xsl:if test="marc:datafield[@tag=490][@ind1=1]">
            <xsl:for-each select="marc:datafield[@tag=800 or @tag=810 or @tag=811 or @tag=830]">
                <xsl:choose>
                    <xsl:when test="$UseControlNumber = '1' and marc:subfield[@code='w']">
                        <a href="/cgi-bin/koha/opac-search.pl?idx=nk&#38;q={marc:subfield[@code='w']}">
                            <xsl:call-template name="chopPunctuation">
                                <xsl:with-param name="chopString">
                                    <xsl:call-template name="subfieldSelect">
                                        <xsl:with-param name="codes">a_t</xsl:with-param>
                                    </xsl:call-template>
                                </xsl:with-param>
                            </xsl:call-template>
                        </a>
                    </xsl:when>
                    <xsl:otherwise>
                        <a><xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=se,phr:"<xsl:value-of select="marc:subfield[@code='a']"/>"</xsl:attribute>
                            <xsl:call-template name="chopPunctuation">
                                <xsl:with-param name="chopString">
                                    <xsl:call-template name="subfieldSelect">
                                        <xsl:with-param name="codes">a_t</xsl:with-param>
                                    </xsl:call-template>
                                </xsl:with-param>
                            </xsl:call-template>
                        </a>
                        <xsl:call-template name="part"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:text>: </xsl:text>
                <xsl:value-of  select="marc:subfield[@code='v']" />
            <xsl:choose><xsl:when test="position()=last()"><xsl:text></xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
            </xsl:for-each>
        </xsl:if>
        </td>
        </tr>
        </xsl:if>

        <!-- Frequency ( Analytics ) -->
        <xsl:if test="$leader7='s'">
        <tr class="frequency"><td class="labelColumn">Frequency: </td><td class="biblioDetail">
            <xsl:for-each select="marc:datafield[@tag=310]">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">a</xsl:with-param>
                    </xsl:call-template>
            </xsl:for-each>
        </td>
        </tr>
        </xsl:if>

        <!-- Volumes of sets and traced series -->
        <xsl:if test="$materialTypeCode='ST' or substring($controlField008,22,1)='m'">
        <tr class="volumes"><td class="labelColumn">Volumes: </td><td class="biblioDetail">
            <a>
            <xsl:choose>
            <xsl:when test="$UseControlNumber = '1' and marc:controlfield[@tag=001]">
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=rcn:<xsl:value-of select="marc:controlfield[@tag=001]"/>+not+(bib-level:a+or+bib-level:b)</xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=ti,phr:<xsl:value-of select="translate(marc:datafield[@tag=245]/marc:subfield[@code='a'], '/', '')"/></xsl:attribute>
            </xsl:otherwise>
            </xsl:choose>
            <xsl:text>Show volumes</xsl:text>
            </a>
        </td>
        </tr>
        </xsl:if>

        <!-- Set -->
        <xsl:if test="$leader19='c'">
        <tr class="set"><td class="labelColumn">Set: </td><td class="biblioDetail">
        <xsl:for-each select="marc:datafield[@tag=773]">
            <a>
            <xsl:choose>
            <xsl:when test="$UseControlNumber = '1' and marc:subfield[@code='w']">
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=nk:<xsl:call-template name="extractControlNumber"><xsl:with-param name="subfieldW" select="marc:subfield[@code='w']"/></xsl:call-template></xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=ti,phr:<xsl:value-of select="translate(//marc:datafield[@tag=245]/marc:subfield[@code='a'], '.', '')"/></xsl:attribute>
            </xsl:otherwise>
            </xsl:choose>
            <xsl:value-of select="translate(//marc:datafield[@tag=245]/marc:subfield[@code='a'], '.', '')" />
            </a>
            <xsl:choose>
                <xsl:when test="position()=last()"></xsl:when>
                <xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        </td>
        </tr>
        </xsl:if>

        <!-- Publisher Statement: Alternate Graphic Representation (MARC 880) -->
        <xsl:if test="$display880">
            <xsl:call-template name="m880Select">
                <xsl:with-param name="basetags">260</xsl:with-param>
                <xsl:with-param name="codes">abcg</xsl:with-param>
                <xsl:with-param name="class">results_summary publisher</xsl:with-param>
                <xsl:with-param name="label">Publisher: </xsl:with-param>
            </xsl:call-template>
        </xsl:if>

        <xsl:if test="marc:datafield[@tag=260]">
        <tr class="publisher"><td class="labelColumn">Publisher: </td><td class="biblioDetail">
            <xsl:for-each select="marc:datafield[@tag=260]">
                <xsl:for-each select="marc:subfield">
                    <xsl:choose>
                    <xsl:when test="@code='b'">
                        <a href="/cgi-bin/koha/opac-search.pl?q=pb:{.}">
                            <xsl:value-of select="."/>
                        </a>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="."/>
                        <xsl:text> </xsl:text>
                    </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                    <xsl:choose><xsl:when test="position()=last()"><xsl:text></xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
            </xsl:for-each>
        </td>
        </tr>
        </xsl:if>

        <!-- Edition Statement: Alternate Graphic Representation (MARC 880) -->
        <xsl:if test="$display880">
            <xsl:call-template name="m880Select">
                <xsl:with-param name="basetags">250</xsl:with-param>
                <xsl:with-param name="codes">ab</xsl:with-param>
                <xsl:with-param name="class">results_summary edition</xsl:with-param>
                <xsl:with-param name="label">Edition: </xsl:with-param>
            </xsl:call-template>
        </xsl:if>

        <xsl:if test="marc:datafield[@tag=250]">
        <tr class="edition"><td class="labelColumn">Edition: </td>
            <td class="biblioDetail">
            <xsl:for-each select="marc:datafield[@tag=250]">
                <xsl:call-template name="chopPunctuation">
                  <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">ab</xsl:with-param>
                    </xsl:call-template>
                   </xsl:with-param>
               </xsl:call-template>
                    <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
            </xsl:for-each>
        </td>
        </tr>
        </xsl:if>

        <!-- Description: Alternate Graphic Representation (MARC 880) -->
        <xsl:if test="$display880">
            <xsl:call-template name="m880Select">
                <xsl:with-param name="basetags">300</xsl:with-param>
                <xsl:with-param name="codes">abceg</xsl:with-param>
                <xsl:with-param name="class">results_summary description</xsl:with-param>
                <xsl:with-param name="label">Description: </xsl:with-param>
            </xsl:call-template>
        </xsl:if>

        <xsl:if test="marc:datafield[@tag=300]">
        <tr class="description"><td class="labelColumn">Description: </td>
            <td class="biblioDetail">
            <xsl:for-each select="marc:datafield[@tag=300]">
                <xsl:call-template name="chopPunctuation">
                  <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">abceg</xsl:with-param>
                    </xsl:call-template>
                   </xsl:with-param>
               </xsl:call-template>
                    <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
            </xsl:for-each>
        </td>
        </tr>
       </xsl:if>

       <xsl:if test="marc:datafield[@tag=020]">
        <tr class="isbn"><td class="labelColumn">ISBN: </td>
        <td class="biblioDetail">
        <xsl:for-each select="marc:datafield[@tag=020]">
        <xsl:variable name="isbn" select="marc:subfield[@code='a']"/>
                <xsl:value-of select="marc:subfield[@code='a']"/>
                <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
        </xsl:for-each>
        </td>
        </tr>
        </xsl:if>

        <xsl:if test="marc:datafield[@tag=022]">
        <tr class="issn"><td class="labelColumn">ISSN: </td><td class ="biblioDetail">
        <xsl:for-each select="marc:datafield[@tag=022]">
                <xsl:value-of select="marc:subfield[@code='a']"/>
                <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
        </xsl:for-each>
        </td>
        </tr>
        </xsl:if>

        <!-- Other Title  Statement: Alternate Graphic Representation (MARC 880) -->
        <xsl:if test="$display880">
            <xsl:call-template name="m880Select">
                <xsl:with-param name="basetags">246</xsl:with-param>
                <xsl:with-param name="codes">abhfgnp</xsl:with-param>
                <xsl:with-param name="class">results_summary other_title</xsl:with-param>
                <xsl:with-param name="label">Other Title: </xsl:with-param>
            </xsl:call-template>
        </xsl:if>

        <xsl:if test="marc:datafield[@tag=246]">
        <tr class="other_title"><td class="labelColumn">Other Title: </td><td class="biblioDetail">
            <xsl:for-each select="marc:datafield[@tag=246]">
                <xsl:call-template name="chopPunctuation">
                  <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">iabhfgnp</xsl:with-param>
                    </xsl:call-template>
                   </xsl:with-param>
               </xsl:call-template>
                    <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
            </xsl:for-each>
        </td>
        </tr>
       </xsl:if>


        <xsl:if test="marc:datafield[@tag=242]">
        <tr class="translated_title"><td class="labelColumn">Title translated: </td><td class="biblioDetail">
            <xsl:for-each select="marc:datafield[@tag=242]">
                <xsl:call-template name="chopPunctuation">
                  <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">abchnp</xsl:with-param>
                    </xsl:call-template>
                   </xsl:with-param>
               </xsl:call-template>
                    <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
            </xsl:for-each>
        </td>
        </tr>
       </xsl:if>

        <!-- Uniform Title  Statement: Alternate Graphic Representation (MARC 880) -->
        <xsl:if test="$display880">
            <xsl:call-template name="m880Select">
                <xsl:with-param name="basetags">130,240</xsl:with-param>
                <xsl:with-param name="codes">adfklmor</xsl:with-param>
                <xsl:with-param name="class">results_summary uniform_title</xsl:with-param>
                <xsl:with-param name="label">Uniform titles: </xsl:with-param>
            </xsl:call-template>
        </xsl:if>

        <xsl:if test="marc:datafield[@tag=130]|marc:datafield[@tag=240]|marc:datafield[@tag=730][@ind2!=2]">
        <tr class="uniform_titles"><td class="labelColumn">Uniform titles: </td><td class="biblioDetail">
        <xsl:for-each select="marc:datafield[@tag=130]|marc:datafield[@tag=240]|marc:datafield[@tag=730][@ind2!=2]">
            <xsl:variable name="str">
                <xsl:for-each select="marc:subfield">
                    <xsl:if test="(contains('adfklmor',@code) and (not(../marc:subfield[@code='n' or @code='p']) or (following-sibling::marc:subfield[@code='n' or @code='p'])))">
                        <xsl:value-of select="text()"/>
                        <xsl:text> </xsl:text>
                     </xsl:if>
                </xsl:for-each>
            </xsl:variable>
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:value-of select="substring($str,1,string-length($str)-1)"/>

                </xsl:with-param>
            </xsl:call-template>
            <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
        </xsl:for-each>
        </td>
        </tr>
        </xsl:if>

        <xsl:if test="marc:datafield[substring(@tag, 1, 1) = '5']">
            <xsl:for-each select="marc:datafield[substring(@tag, 1, 1) = '5']">
                <xsl:choose>
                    <xsl:when test="position()=1">
                        <tr class="notes"><td class="labelColumn">Title notes: </td><td class="biblioDetail">
                        <xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">a</xsl:with-param>
                        </xsl:call-template>
                        </td></tr>
                    </xsl:when>
                    <xsl:otherwise>
                        <tr class="notes"><td class="labelColumn"></td><td class="biblioDetail">
                        <xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">a</xsl:with-param>
                        </xsl:call-template>
                        </td></tr>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:if>

        <xsl:if test="marc:datafield[substring(@tag, 1, 1) = '6']">
            <tr class="subjects"><td class="labelColumn">Subject(s): </td><td class="biblioDetail">
            <xsl:for-each select="marc:datafield[substring(@tag, 1, 1) = '6']">
            <a>
            <xsl:choose>
            <xsl:when test="marc:subfield[@code=9] and $UseAuthoritiesForTracings='1'">
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=an:<xsl:value-of select="marc:subfield[@code=9]"/></xsl:attribute>
            </xsl:when>
            <xsl:when test="$TraceSubjectSubdivisions='1'">
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=<xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">abcdfgklmnopqrstvxyz</xsl:with-param>
                        <xsl:with-param name="delimeter"> AND </xsl:with-param>
                        <xsl:with-param name="prefix">(su<xsl:value-of select="$SubjectModifier"/>:<xsl:value-of select="$TracingQuotesLeft"/></xsl:with-param>
                        <xsl:with-param name="suffix"><xsl:value-of select="$TracingQuotesRight"/>)</xsl:with-param>
                    </xsl:call-template>
                </xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=su<xsl:value-of select="$SubjectModifier"/>:<xsl:value-of select="$TracingQuotesLeft"/><xsl:value-of select="marc:subfield[@code='a']"/><xsl:value-of select="$TracingQuotesRight"/></xsl:attribute>
            </xsl:otherwise>
            </xsl:choose>
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">abcdfgklmnopqrstvxyz</xsl:with-param>
                        <xsl:with-param name="subdivCodes">vxyz</xsl:with-param>
                        <xsl:with-param name="subdivDelimiter">-- </xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
            </xsl:call-template>
            </a>
            <xsl:if test="marc:subfield[@code=9]">
                <a class='authlink'>
                    <xsl:attribute name="href">/cgi-bin/koha/opac-authoritiesdetail.pl?authid=<xsl:value-of select="marc:subfield[@code=9]"/></xsl:attribute>
                    <xsl:element name="img">
                        <xsl:attribute name="src">/opac-tmpl/<xsl:value-of select="$theme"/>/images/filefind.png</xsl:attribute>
                        <xsl:attribute name="style">vertical-align:middle</xsl:attribute>
                        <xsl:attribute name="height">15</xsl:attribute>
                        <xsl:attribute name="width">15</xsl:attribute>
                    </xsl:element>
                </a>
            </xsl:if>
            <xsl:choose>
            <xsl:when test="position()=last()"></xsl:when>
            <xsl:otherwise><br/></xsl:otherwise>
            </xsl:choose>

            </xsl:for-each>
            </td>
            </tr>
        </xsl:if>

        <xsl:if test="marc:datafield[substring(@tag, 1, 2) = '70'or substring(@tag, 1, 2) = '71' or substring(@tag, 1, 2) = '72' or substring(@tag, 1, 2) = '73' or substring(@tag, 1, 2) = '74']">
            <tr class="subjects"><td class="labelColumn">Alt Author: </td><td class="biblioDetail">
            <xsl:for-each select="marc:datafield[substring(@tag, 1, 2) = '70'or substring(@tag, 1, 2) = '71' or substring(@tag, 1, 2) = '72' or substring(@tag, 1, 2) = '73' or substring(@tag, 1, 2) = '74']">

            <a>
            <xsl:choose>
            <xsl:when test="marc:subfield[@code=9] and $UseAuthoritiesForTracings='1'">
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=an:<xsl:value-of select="marc:subfield[@code=9]"/></xsl:attribute>
            </xsl:when>
            <xsl:when test="$TraceSubjectSubdivisions='1'">
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=<xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">abcdfgklmnopqrstvxyz</xsl:with-param>
                        <xsl:with-param name="delimeter"> AND </xsl:with-param>
                        <xsl:with-param name="prefix">(<xsl:value-of select="$TracingQuotesLeft"/></xsl:with-param>
                        <xsl:with-param name="suffix"><xsl:value-of select="$TracingQuotesRight"/>)</xsl:with-param>
                    </xsl:call-template>
                </xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=<xsl:value-of select="$TracingQuotesLeft"/><xsl:value-of select="marc:subfield[@code='a']"/><xsl:value-of select="$TracingQuotesRight"/></xsl:attribute>
            </xsl:otherwise>
            </xsl:choose>
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">abcdfgklmnopqrstvxyz</xsl:with-param>
                        <xsl:with-param name="subdivCodes">vxyz</xsl:with-param>
                        <xsl:with-param name="subdivDelimiter">-- </xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
            </xsl:call-template>
            </a>
            <xsl:if test="marc:subfield[@code=9]">
                <a class='authlink'>
                    <xsl:attribute name="href">/cgi-bin/koha/opac-authoritiesdetail.pl?authid=<xsl:value-of select="marc:subfield[@code=9]"/></xsl:attribute>
                    <img style="vertical-align:middle" height="15" width="15" src="/opac-tmpl/bootstrap/images/filefind.png"/>
                </a>
            </xsl:if>
            <xsl:choose>
            <xsl:when test="position()=last()"></xsl:when>
            <xsl:otherwise><br/></xsl:otherwise>
            </xsl:choose>

            </xsl:for-each>
            </td>
            </tr>
        </xsl:if>
<!-- Image processing code added here, takes precedence over text links including y3z text   -->
        <xsl:if test="marc:datafield[@tag=856]">
        <tr class="online_resources"><td class="labelColumn">Online Resources: </td><td class="biblioDetail">
        <xsl:for-each select="marc:datafield[@tag=856]">
            <xsl:variable name="SubqText"><xsl:value-of select="marc:subfield[@code='q']"/></xsl:variable>
            <a><xsl:attribute name="href"><xsl:value-of select="marc:subfield[@code='u']"/></xsl:attribute>
            <xsl:if test="$OPACURLOpenInNewWindow='1'">
                <xsl:attribute name="target">_blank</xsl:attribute>
            </xsl:if>
            <xsl:choose>
            <xsl:when test="($Show856uAsImage='Details' or $Show856uAsImage='Both') and (substring($SubqText,1,6)='image/' or $SubqText='img' or $SubqText='bmp' or $SubqText='cod' or $SubqText='gif' or $SubqText='ief' or $SubqText='jpe' or $SubqText='jpeg' or $SubqText='jpg' or $SubqText='jfif' or $SubqText='png' or $SubqText='svg' or $SubqText='tif' or $SubqText='tiff' or $SubqText='ras' or $SubqText='cmx' or $SubqText='ico' or $SubqText='pnm' or $SubqText='pbm' or $SubqText='pgm' or $SubqText='ppm' or $SubqText='rgb' or $SubqText='xbm' or $SubqText='xpm' or $SubqText='xwd')">
                <xsl:element name="img"><xsl:attribute name="src"><xsl:value-of select="marc:subfield[@code='u']"/></xsl:attribute><xsl:attribute name="alt"><xsl:value-of select="marc:subfield[@code='y']"/></xsl:attribute><xsl:attribute name="style">height:100px</xsl:attribute></xsl:element><xsl:text></xsl:text>
            </xsl:when>
            <xsl:when test="marc:subfield[@code='y' or @code='3' or @code='z']">
                <xsl:call-template name="subfieldSelect">
                    <xsl:with-param name="codes">y3z</xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$URLLinkText!=''">
                <xsl:value-of select="$URLLinkText"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>Click here to access online</xsl:text>
            </xsl:otherwise>
            </xsl:choose>
            </a>
            <xsl:choose>
            <xsl:when test="position()=last()"><xsl:text>  </xsl:text></xsl:when>
            <xsl:otherwise> | </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        </td>
        </tr>
        </xsl:if>

        <!-- 530 -->
 <!--
        <xsl:if test="marc:datafield[@tag=530]">
        <xsl:for-each select="marc:datafield[@tag=530]">
        <tr class="additionalforms"><td class="labelColumn"></td><td class="biblioDetail">
            <xsl:call-template name="subfieldSelect">
                <xsl:with-param name="codes">abcd</xsl:with-param>
            </xsl:call-template>
            <xsl:for-each select="marc:subfield[@code='u']">
                <a><xsl:attribute name="href"><xsl:value-of select="text()"/></xsl:attribute>
                <xsl:if test="$OPACURLOpenInNewWindow='1'">
                    <xsl:attribute name="target">_blank</xsl:attribute>
                </xsl:if>
                <xsl:value-of select="text()"/>
                </a>
            </xsl:for-each>
        </td>
        </tr>
        </xsl:for-each>
        </xsl:if>
-->
        <!-- 505 -->
<!--
        <xsl:if test="marc:datafield[@tag=505]">
        <tr class="contents">
        <xsl:for-each select="marc:datafield[@tag=505]">
        <xsl:if test="position()=1">
            <xsl:choose>
            <xsl:when test="@ind1=1">
                <td class="labelColumn">Incomplete contents:</td>
            </xsl:when>
            <xsl:when test="@ind1=2">
                <td class="labelColumn">Partial contents:</td>
            </xsl:when>
            <xsl:otherwise>
                <td class="labelColumn">Contents:</td>
            </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
        <td>
        <div class='contentblock'>
        <xsl:choose>
        <xsl:when test="@ind2=0">
            <xsl:call-template name="subfieldSelectSpan">
                <xsl:with-param name="codes">tru</xsl:with-param>
            </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
            <xsl:call-template name="subfieldSelectSpan">
                <xsl:with-param name="codes">atru</xsl:with-param>
            </xsl:call-template>
        </xsl:otherwise>
        </xsl:choose>
        </div>
        </td>
        </xsl:for-each>
        </tr>
        </xsl:if>
-->
        <!-- 583 -->
<!--
        <xsl:if test="marc:datafield[@tag=583]">
        <xsl:for-each select="marc:datafield[@tag=583]">
            <xsl:if test="@ind1=1 or @ind1=' '">
            <tr class="actionnote"><td class="labelColumn"></td><td class="biblioDetail">
                <xsl:choose>
                <xsl:when test="marc:subfield[@code='z']">
                    <xsl:value-of select="marc:subfield[@code='z']"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">abcdefgijklnou</xsl:with-param>
                    </xsl:call-template>
                </xsl:otherwise>
                </xsl:choose>
            </td>
            </tr>
            </xsl:if>
        </xsl:for-each>
        </xsl:if>
-->
        <!-- 586 -->
<!--
        <xsl:if test="marc:datafield[@tag=586]">
        <xsl:for-each select="marc:datafield[@tag=586]">
            <tr class="awardsnote">
                <xsl:if test="@ind1=' '">
                <td class="labelColumn">Awards: </td>
                </xsl:if>
                <td class="biblioDetail">
                <xsl:value-of select="marc:subfield[@code='a']"/></td>
            </tr>
        </xsl:for-each>
        </xsl:if>
-->
        <!-- 773 -->

        <xsl:if test="marc:datafield[@tag=773]">
        <xsl:for-each select="marc:datafield[@tag=773]">
        <xsl:if test="@ind1=0">
        <tr class="in"><td class="labelColumn">
        <xsl:choose>
        <xsl:when test="@ind2=' '">
            In:
        </xsl:when>
        <xsl:when test="@ind2=8">
            <xsl:if test="marc:subfield[@code='i']">
                <xsl:value-of select="marc:subfield[@code='i']"/>
            </xsl:if>
        </xsl:when>
        </xsl:choose>
        </td><td class="biblioDetail">
                <xsl:variable name="f773">
                    <xsl:call-template name="chopPunctuation"><xsl:with-param name="chopString"><xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">a_t</xsl:with-param>
                    </xsl:call-template></xsl:with-param></xsl:call-template>
                </xsl:variable>
            <xsl:choose>
                <xsl:when test="$UseControlNumber = '1' and marc:subfield[@code='w']">
                    <a><xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?idx=nk&#38;q=<xsl:call-template name="extractControlNumber"><xsl:with-param name="subfieldW" select="marc:subfield[@code='w']"/></xsl:call-template></xsl:attribute>
                        <xsl:value-of select="translate($f773, '()', '')"/>
                    </a>
                    <xsl:if test="marc:subfield[@code='g']"><xsl:text> </xsl:text><xsl:value-of select="marc:subfield[@code='g']"/></xsl:if>
                </xsl:when>
                <xsl:when test="marc:subfield[@code='0']">
                    <a><xsl:attribute name="href">/cgi-bin/koha/opac-detail.pl?biblionumber=<xsl:value-of select="marc:subfield[@code='0']"/></xsl:attribute>
                        <xsl:value-of select="$f773"/>
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <a><xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=ti,phr:<xsl:value-of select="translate($f773, '()', '')"/></xsl:attribute>
                        <xsl:value-of select="$f773"/>
                    </a>
                    <xsl:if test="marc:subfield[@code='g']"><xsl:text> </xsl:text><xsl:value-of select="marc:subfield[@code='g']"/></xsl:if>
                </xsl:otherwise>
            </xsl:choose>
        </td>
        </tr>

        <xsl:if test="marc:subfield[@code='n']">
            <tr class="in">
            <td class="labelColumn"></td>
            <td class="results_summary"><xsl:value-of select="marc:subfield[@code='n']"/></td>
            </tr>
        </xsl:if>

        </xsl:if>
        </xsl:for-each>
        </xsl:if>

        <xsl:for-each select="marc:datafield[@tag=520]">
        <tr class="summary"><td class="labelColumn">
        <xsl:choose>
          <xsl:when test="@ind1=0"><xsl:text>Subject: </xsl:text></xsl:when>
          <xsl:when test="@ind1=1"><xsl:text>Review: </xsl:text></xsl:when>
          <xsl:when test="@ind1=2"><xsl:text>Scope and content: </xsl:text></xsl:when>
          <xsl:when test="@ind1=3"><xsl:text>Abstract: </xsl:text></xsl:when>
          <xsl:when test="@ind1=4"><xsl:text>Content advice: </xsl:text></xsl:when>
          <xsl:otherwise><xsl:text>Summary: </xsl:text></xsl:otherwise>
        </xsl:choose>
        </td><td class="biblioDetail">
        <xsl:call-template name="subfieldSelect">
          <xsl:with-param name="codes">abcu</xsl:with-param>
        </xsl:call-template>
        </td>
        </tr>
        </xsl:for-each>

        <!-- 866 textual holdings -->
        <xsl:if test="marc:datafield[@tag=866]">
            <tr class="holdings_note"><td class="labelColumn">Holdings Note: </td><td class="biblioDetail">
                <xsl:for-each select="marc:datafield[@tag=866]">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">az</xsl:with-param>
                    </xsl:call-template>
                    <xsl:choose><xsl:when test="position()=last()"><xsl:text></xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
                </xsl:for-each>
            </td>
            </tr>
        </xsl:if>

        <!--  775 Other Edition  -->
        <xsl:if test="marc:datafield[@tag=775]">
        <tr class="other_editions"><td class="labelColumn">Other Editions: </td><td class="biblioDetail">
        <xsl:for-each select="marc:datafield[@tag=775]">
            <xsl:variable name="f775">
                <xsl:call-template name="chopPunctuation"><xsl:with-param name="chopString"><xsl:call-template name="subfieldSelect">
                <xsl:with-param name="codes">a_t</xsl:with-param>
                </xsl:call-template></xsl:with-param></xsl:call-template>
            </xsl:variable>
            <xsl:if test="marc:subfield[@code='i']">
                <xsl:call-template name="subfieldSelect">
                    <xsl:with-param name="codes">i</xsl:with-param>
                </xsl:call-template>
                <xsl:text>: </xsl:text>
            </xsl:if>
            <a>
            <xsl:choose>
            <xsl:when test="$UseControlNumber = '1' and marc:subfield[@code='w']">
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?idx=nk&#38;q=<xsl:call-template name="extractControlNumber"><xsl:with-param name="subfieldW" select="marc:subfield[@code='w']"/></xsl:call-template></xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=ti,phr:<xsl:value-of select="translate($f775, '()', '')"/></xsl:attribute>
            </xsl:otherwise>
            </xsl:choose>
            <xsl:call-template name="subfieldSelect">
                <xsl:with-param name="codes">a_t</xsl:with-param>
            </xsl:call-template>
            </a>
            <xsl:choose>
                <xsl:when test="position()=last()"></xsl:when>
                <xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        </td>
        </tr>
        </xsl:if>

        <!-- 780 -->
        <xsl:if test="marc:datafield[@tag=780]">
        <xsl:for-each select="marc:datafield[@tag=780]">

        <xsl:if test="@ind1=0">
        <tr class="preceeding_entry">
        <xsl:choose>
        <xsl:when test="@ind2=0">
            <td class="labelColumn">Continues:</td>
        </xsl:when>
        <xsl:when test="@ind2=1">
            <td class="labelColumn">Continues in part:</td>
        </xsl:when>
        <xsl:when test="@ind2=2">
            <td class="labelColumn">Supersedes:</td>
        </xsl:when>
        <xsl:when test="@ind2=3">
            <td class="labelColumn">Supersedes in part:</td>
        </xsl:when>
        <xsl:when test="@ind2=4">
            <td class="labelColumn">Formed by the union: ... and: ...</td>
        </xsl:when>
        <xsl:when test="@ind2=5">
            <td class="labelColumn">Absorbed:</td>
        </xsl:when>
        <xsl:when test="@ind2=6">
            <td class="labelColumn">Absorbed in part:</td>
        </xsl:when>
        <xsl:when test="@ind2=7">
            <td class="labelColumn">Separated from:</td>
        </xsl:when>
        </xsl:choose>
        <td class="biblioDetail">
                <xsl:variable name="f780">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">a_t</xsl:with-param>
                    </xsl:call-template>
                </xsl:variable>
            <xsl:choose>
                <xsl:when test="$UseControlNumber = '1' and marc:subfield[@code='w']">
                    <a><xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?idx=nk&#38;q=<xsl:call-template name="extractControlNumber"><xsl:with-param name="subfieldW" select="marc:subfield[@code='w']"/></xsl:call-template></xsl:attribute>
                        <xsl:value-of select="translate($f780, '()', '')"/>
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <a><xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=<xsl:value-of select="translate($f780, '()', '')"/></xsl:attribute>
                        <xsl:value-of select="translate($f780, '()', '')"/>
                    </a>
                </xsl:otherwise>
            </xsl:choose>
        </td>
        </tr>

        <xsl:if test="marc:subfield[@code='n']">
            <tr class="labelColumn"></tr>
            <td class="results_summary"><xsl:value-of select="marc:subfield[@code='n']"/></td>
        </xsl:if>
        </xsl:if>
        </xsl:for-each>
        </xsl:if>

        <!-- 785 -->
        <xsl:if test="marc:datafield[@tag=785]">
        <xsl:for-each select="marc:datafield[@tag=785]">
        <xsl:if test="@ind1=0">
        <tr class="succeeding_entry">
        <xsl:choose>
        <xsl:when test="@ind2=0">
            <td class="labelColumn">Continued by:</td>
        </xsl:when>
        <xsl:when test="@ind2=1">
            <td class="labelColumn">Continued in part by:</td>
        </xsl:when>
        <xsl:when test="@ind2=2">
            <td class="labelColumn">Superseded by:</td>
        </xsl:when>
        <xsl:when test="@ind2=3">
            <td class="labelColumn">Superseded in part by:</td>
        </xsl:when>
        <xsl:when test="@ind2=4">
            <td class="labelColumn">Absorbed by:</td>
        </xsl:when>
        <xsl:when test="@ind2=5">
            <td class="labelColumn">Absorbed in part by:</td>
        </xsl:when>
        <xsl:when test="@ind2=6">
            <td class="labelColumn">Split into .. and ...:</td>
        </xsl:when>
        <xsl:when test="@ind2=7">
            <td class="labelColumn">Merged with ... to form ...</td>
        </xsl:when>
        <xsl:when test="@ind2=8">
            <td class="labelColumn">Changed back to:</td>
        </xsl:when>
        </xsl:choose>
        <td class="biblioDetail">
                   <xsl:variable name="f785">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">a_t</xsl:with-param>
                    </xsl:call-template>
                </xsl:variable>

            <xsl:choose>
                <xsl:when test="$UseControlNumber = '1' and marc:subfield[@code='w']">
                    <a><xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?idx=nk&#38;q=<xsl:call-template name="extractControlNumber"><xsl:with-param name="subfieldW" select="marc:subfield[@code='w']"/></xsl:call-template></xsl:attribute>
                        <xsl:value-of select="translate($f785, '()', '')"/>
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <a><xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=<xsl:value-of select="translate($f785, '()', '')"/></xsl:attribute>
                        <xsl:value-of select="translate($f785, '()', '')"/>
                    </a>
                </xsl:otherwise>
            </xsl:choose>
        </td>
        </tr>

        <xsl:if test="marc:subfield[@code='n']">
            <tr class="labelColumn"></tr>
            <td class="results_summary"><xsl:value-of select="marc:subfield[@code='n']"/></td>
        </xsl:if>
        </xsl:if>
        </xsl:for-each>
        </xsl:if>
        </table>
    </xsl:template>

    <xsl:template name="showAuthor">
        <xsl:param name="authorfield" />
        <xsl:param name="UseAuthoritiesForTracings" />
        <xsl:param name="materialTypeLabel" />
        <xsl:param name="theme" />
        <xsl:for-each select="$authorfield">
            <xsl:choose><xsl:when test="position()!=1"><xsl:text>; </xsl:text></xsl:when></xsl:choose>
            <xsl:choose>
                <xsl:when test="not(@tag=111 or @tag=711)" />
                <xsl:when test="marc:subfield[@code='n']">
                    <xsl:text> </xsl:text>
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">n</xsl:with-param>
                    </xsl:call-template>
                    <xsl:text> </xsl:text>
                </xsl:when>
            </xsl:choose>
            <a>
                <xsl:choose>
                    <xsl:when test="marc:subfield[@code=9] and $UseAuthoritiesForTracings='1'">
                        <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=an:<xsl:value-of select="marc:subfield[@code=9]"/></xsl:attribute>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=au:<xsl:value-of select="marc:subfield[@code='a']"/></xsl:attribute>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:choose>
                    <xsl:when test="@tag=100 or @tag=700"><xsl:call-template name="nameABCDQ"/></xsl:when>
                    <xsl:when test="@tag=110 or @tag=710"><xsl:call-template name="nameABCDN"/></xsl:when>
                    <xsl:when test="@tag=111 or @tag=711"><xsl:call-template name="nameACDEQ"/></xsl:when>
                </xsl:choose>
                <!-- add relator code too between brackets-->
                <xsl:if test="marc:subfield[@code='4' or @code='e']">
                    <span class="relatorcode">
                    <xsl:text> [</xsl:text>
                    <xsl:choose>
                        <xsl:when test="marc:subfield[@code=4]"><xsl:value-of select="marc:subfield[@code=4]"/></xsl:when>
                        <xsl:otherwise><xsl:value-of select="marc:subfield[@code='e']"/></xsl:otherwise>
                    </xsl:choose>
                    <xsl:text>]</xsl:text>
                    </span>
                </xsl:if>
            </a>
            <xsl:if test="marc:subfield[@code=9]">
                <a class='authlink'>
                    <xsl:attribute name="href">/cgi-bin/koha/opac-authoritiesdetail.pl?authid=<xsl:value-of select="marc:subfield[@code=9]"/></xsl:attribute>
                    <xsl:element name="img">
                        <xsl:attribute name="src">/opac-tmpl/<xsl:value-of select="$theme"/>/images/filefind.png</xsl:attribute>
                        <xsl:attribute name="style">vertical-align:middle</xsl:attribute>
                        <xsl:attribute name="height">15</xsl:attribute>
                        <xsl:attribute name="width">15</xsl:attribute>
                    </xsl:element>
                </a>
            </xsl:if>
        </xsl:for-each>
        <xsl:text>.</xsl:text>
    </xsl:template>

    <xsl:template name="nameABCDQ">
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">aq</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
                <xsl:with-param name="punctuation">
                    <xsl:text>:,;/ </xsl:text>
                </xsl:with-param>
            </xsl:call-template>
        <xsl:call-template name="termsOfAddress"/>
    </xsl:template>

    <xsl:template name="nameABCDN">
        <xsl:for-each select="marc:subfield[@code='a']">
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString" select="."/>
                </xsl:call-template>
        </xsl:for-each>
        <xsl:for-each select="marc:subfield[@code='b']">
            <xsl:value-of select="."/>
            <xsl:choose>
                <xsl:when test="position() != last()">
                    <xsl:text> -- </xsl:text>
                </xsl:when>
            </xsl:choose>
        </xsl:for-each>
        <xsl:if test="marc:subfield[@code='c'] or marc:subfield[@code='d'] or marc:subfield[@code='n']">
                <xsl:call-template name="subfieldSelect">
                    <xsl:with-param name="codes">cdn</xsl:with-param>
                </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="nameACDEQ">
            <xsl:call-template name="subfieldSelect">
                <xsl:with-param name="codes">acdeq</xsl:with-param>
            </xsl:call-template>
    </xsl:template>
    <xsl:template name="termsOfAddress">
        <xsl:if test="marc:subfield[@code='b' or @code='c']">
            <xsl:text> </xsl:text>
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">bcd</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="part">
        <xsl:variable name="partNumber">
            <xsl:call-template name="specialSubfieldSelect">
                <xsl:with-param name="axis">n</xsl:with-param>
                <xsl:with-param name="anyCodes">n</xsl:with-param>
                <xsl:with-param name="afterCodes">fghkdlmor</xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="partName">
            <xsl:call-template name="specialSubfieldSelect">
                <xsl:with-param name="axis">p</xsl:with-param>
                <xsl:with-param name="anyCodes">p</xsl:with-param>
                <xsl:with-param name="afterCodes">fghkdlmor</xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        <xsl:if test="string-length(normalize-space($partNumber))">
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString" select="$partNumber"/>
                </xsl:call-template>
        </xsl:if>
        <xsl:if test="string-length(normalize-space($partName))">
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString" select="$partName"/>
                </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="specialSubfieldSelect">
        <xsl:param name="anyCodes"/>
        <xsl:param name="axis"/>
        <xsl:param name="beforeCodes"/>
        <xsl:param name="afterCodes"/>
        <xsl:variable name="str">
            <xsl:for-each select="marc:subfield">
                <xsl:if test="contains($anyCodes, @code)      or (contains($beforeCodes,@code) and following-sibling::marc:subfield[@code=$axis])      or (contains($afterCodes,@code) and preceding-sibling::marc:subfield[@code=$axis])">
                    <xsl:value-of select="text()"/>
                    <xsl:text> </xsl:text>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="substring($str,1,string-length($str)-1)"/>
    </xsl:template>
</xsl:stylesheet>
