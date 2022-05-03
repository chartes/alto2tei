<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="1.1"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:alto="http://www.loc.gov/standards/alto/ns-v4#"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="alto tei"
  >
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  <xsl:variable name="lf" select="'&#10;'"/>
  <xsl:variable name="num">0123456789</xsl:variable>
  <!-- Majuscules, pour conversions. -->
  <xsl:variable name="caps">ABCDEFGHIJKLMNOPQRSTUVWXYZÆŒÇÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝ</xsl:variable>
  <!-- Minuscules, pour conversions -->
  <xsl:variable name="mins">abcdefghijklmnopqrstuvwxyzæœçàáâãäåèéêëìíîïòóôõöùúûüý</xsl:variable>
  
  <xsl:template match="/">
    <!-- <xsl:processing-instruction name="xml-model">href="http://svn.code.sf.net/p/algone/code/teibook/teibook.rng" type="application/xml"  schematypens="http://relaxng.org/ns/structure/1.0"</xsl:processing-instruction> -->
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="node() | @*">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="tei:body">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates select="*"/>
      <xsl:call-template name="divClose">
        <xsl:with-param name="n" select=".//tei:head[position() = last()]/@n"/>
      </xsl:call-template>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="tei:book">
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="tei:page">
    <pb>
      <xsl:copy-of select="@facs|@n"/>
    </pb>
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template name="divClose">
    <xsl:param name="n"/>
    <xsl:choose>
      <xsl:when test="$n &gt; 0">
        <xsl:processing-instruction name="div">/</xsl:processing-instruction>
        <xsl:call-template name="divClose">
          <xsl:with-param name="n" select="$n - 1"/>
        </xsl:call-template>
      </xsl:when>     
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="divOpen">
    <xsl:param name="n"/>
    <xsl:choose>
      <xsl:when test="$n &gt; 0">
        <xsl:processing-instruction name="div"/>
        <xsl:call-template name="divOpen">
          <xsl:with-param name="n" select="$n - 1"/>
        </xsl:call-template>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="tei:head">
    <xsl:variable name="level" select="@n"/>
    <xsl:variable name="prev" select="preceding::tei:head[1]/@n"/>
    <xsl:if test="$prev">
      <xsl:call-template name="divClose">
        <xsl:with-param name="n" select="1+ $prev - $level"/>
      </xsl:call-template>
    </xsl:if>
    <!-- Always one -->
    <xsl:call-template name="divOpen">
      <xsl:with-param name="n" select="1"/>
    </xsl:call-template>
    <!-- Sometimes more  -->
    <xsl:variable name="open">
      <xsl:choose>
        <xsl:when test="$prev">
          <xsl:value-of select="$level - $prev - 1"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$level - 1"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:call-template name="divOpen">
      <xsl:with-param name="n" select="$open"/>
    </xsl:call-template>
    <xsl:copy>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="tei:b | tei:i | tei:sub | tei:u ">
    <hi rend="{local-name()}">
      <xsl:apply-templates/>
    </hi>
  </xsl:template>
  
  <xsl:template match="tei:sup">
    <xsl:variable name="text" select="."/>
    <xsl:choose>
      <xsl:when test="translate(., $num, '') != ''">
        <hi rend="sup">
          <xsl:apply-templates/>
        </hi>
      </xsl:when>
      <xsl:otherwise>
        <hi rend="sup">
          <xsl:apply-templates/>
        </hi>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
    
  <!-- 
    Attention aux blocs qui raccrochent par erreur une ligne <small>
    *[tei:small and not(*[local-name()!='small'])] => suffit sans fac-simile
    *[tei:small and *[not(local-name()='lb') or not(local-name()='small')]] => pour conserver le lien à la zone (lb/facs)
    -->
  <xsl:template match="*[tei:small and *[not(local-name()='lb') or not(local-name()='small')]]">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:attribute name="rend">
        <xsl:value-of select="normalize-space(concat(@rend, ' ', 'small'))"/>
      </xsl:attribute>
      <xsl:apply-templates select="text()|*/node()|tei:lb"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="tei:fw"/><!-- sortir l’en-tête inférée en pré-traitement (PRE_REGEXES) -->
  
  <xsl:template match="tei:head[@n='1']/text()">
    <xsl:value-of select="substring(., 1 , 1)"/>
    <xsl:value-of select="translate(substring(., 2), $caps, $mins)"/>
  </xsl:template>
  
  <!-- Pour débogage afficher un path -->
  <xsl:template name="idpath">
    <xsl:for-each select="ancestor-or-self::*">
      <xsl:text>/</xsl:text>
      <xsl:value-of select="name()"/>
      <xsl:if test="count(../*[name()=name(current())]) &gt; 1">
        <xsl:text>[</xsl:text>
        <xsl:number/>
        <xsl:text>]</xsl:text>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  
  <!-- SegmOnto processing for TextBlock -->
  <xsl:template match="tei:p[@type]">
    <xsl:choose>
      <xsl:when test="@type='RunningTitle' or @type='Numbering'">
        <fw>
          <xsl:attribute name="type">
            <xsl:choose>
              <xsl:when test="@type='RunningTitle'">head</xsl:when>
              <xsl:when test="@type='Numbering'">pageNum</xsl:when>
            </xsl:choose>
          </xsl:attribute>
          <xsl:apply-templates/>
        </fw>        
      </xsl:when>
      <xsl:when test="@type='Main'">
        <p>
          <xsl:apply-templates/>
        </p>
      </xsl:when>
      <!-- ? authorized values: DropCapital, Decoration, Rubric… -->
      <xsl:otherwise>
        <p>
          <xsl:attribute name="rend">
            <xsl:value-of select="@type"/>
          </xsl:attribute>
          <xsl:apply-templates/>
        </p>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- SegmOnto processing for TextLine -->
  <xsl:template match="tei:span[@type]">
    <xsl:choose>
      <xsl:when test="@type='Default'">
        <xsl:apply-templates/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
</xsl:transform>