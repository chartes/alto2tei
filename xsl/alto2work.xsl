<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="1.1"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:alto="http://www.loc.gov/standards/alto/ns-v4#"
  xmlns="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="alto"
  >
  <xsl:output method="xml" indent="no" encoding="UTF-8" omit-xml-declaration="yes"/>
  <xsl:key name="style" match="alto:TextStyle | alto:ParagraphStyle" use="@ID"/>
  <xsl:key name="type" match="alto:OtherTag" use="@ID"/>
  <xsl:variable name="lf" select="'&#10;'"/><!-- LF, saut de ligne -->
  <xsl:param name="page_id"/>
  <xsl:param name="no_facsimile"/>
  
  <xsl:template match="/">
    <book>
      <xsl:apply-templates/>
    </book>
  </xsl:template>
  
  <xsl:template match="alto:Page">
    <page>
      <xsl:attribute name="xml:id">
        <xsl:text>P_</xsl:text>
        <xsl:value-of select="$page_id"/>
        <xsl:text>_</xsl:text>
        <xsl:value-of select="@ID"/>
      </xsl:attribute>
      <xsl:attribute name="n">
        <xsl:value-of select="@PHYSICAL_IMG_NR"/>
      </xsl:attribute>
      <xsl:if test="//alto:fileIdentifier">
        <xsl:attribute name="facs">
          <xsl:value-of select="//alto:fileIdentifier"/>
        </xsl:attribute>        
      </xsl:if>
      <xsl:if test="@PAGECLASS">
        <xsl:attribute name="type">
          <xsl:value-of select="@PAGECLASS"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="*"/>
      <xsl:value-of select="$lf"/>
    </page>    
  </xsl:template>
  
  <xsl:template match="*">
    <xsl:apply-templates select="*"/>
  </xsl:template>
  
  <xsl:template match="alto:TextBlock">
    <!-- TODO sort by vertical pos -->
    <xsl:variable name="style">
      <xsl:call-template name="style"/>
    </xsl:variable>
    <xsl:variable name="type">
      <xsl:call-template name="type"/>
    </xsl:variable>
    <xsl:value-of select="$lf"/>
    <p>
      <xsl:if test="normalize-space($type) != ''">
        <xsl:attribute name="type">
          <xsl:value-of select="normalize-space($type)"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="normalize-space($style) != ''">
        <xsl:attribute name="rend">
          <xsl:value-of select="normalize-space($style)"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="*"/>
      <xsl:value-of select="$lf"/>
    </p>
  </xsl:template>
  
  <xsl:template match="alto:TextLine">
    <xsl:variable name="style">
      <xsl:call-template name="style"/>
      <xsl:text> </xsl:text>
    </xsl:variable>
    <xsl:variable name="type">
      <xsl:call-template name="type"/>
    </xsl:variable>
    <xsl:value-of select="$lf"/>
    <xsl:variable name="size" select="normalize-space(substring-before(substring-after($style, 'size'), ' '))"/>
    <xsl:variable name="span">
      <xsl:choose>
        <!-- pb sur de l’italique globale avec de l’italique locale -->
        <xsl:when test="false() and contains($style, 'italics')">
          <i>
            <xsl:apply-templates select="*"/>
          </i>
        </xsl:when>
        <!-- conserver le type de ligne (SegmOnto) -->
        <xsl:when test="$type != ''">
          <span>
            <xsl:attribute name="type">
              <xsl:value-of select="$type"/>
            </xsl:attribute>
            <xsl:apply-templates select="*"/>
          </span>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="*"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <!-- impression optionnelle des identifiants de zone -->
    <xsl:if test="$no_facsimile = 1">
      <lb>
        <xsl:attribute name="facs">
          <xsl:text>#</xsl:text>
          <xsl:value-of select="@ID"/>
        </xsl:attribute>
      </lb>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="$size &lt; 10">
        <small>
          <xsl:copy-of select="$span"/>
        </small>
      </xsl:when>
      <xsl:when test="$size &gt; 12">
        <big>
          <xsl:copy-of select="$span"/>
        </big>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="$span"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="type">
    <xsl:param name="name" select="normalize-space(@TAGREFS)"/>
    <xsl:choose>
      <xsl:when test="normalize-space($name) = ''"/>
      <xsl:otherwise>
        <xsl:variable name="type" select="key('type', $name)"/>
        <xsl:value-of select="$type/@LABEL"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="style">
    <xsl:param name="name" select="normalize-space(@STYLEREFS)"/>
    <xsl:choose>
      <xsl:when test="normalize-space($name) = ''"/>
      <xsl:when test="contains($name, ' ')">
        <xsl:call-template name="style">
          <xsl:with-param name="name" select="substring-before($name, ' ')"/>
        </xsl:call-template>
        <xsl:call-template name="style">
          <xsl:with-param name="name" select="substring-after($name, ' ')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="style" select="key('style', $name)"/>
        <xsl:choose>
          <xsl:when test="$style/@ALIGN = 'Block'"> block</xsl:when>
          <xsl:when test="$style/@ALIGN = 'Center'"> center</xsl:when>
          <xsl:when test="$style/@ALIGN = 'Right'"> right</xsl:when>
        </xsl:choose>
        <xsl:if test="number($style/@LINESPACE) &gt;= 15"> big</xsl:if>
        <xsl:if test="number($style/@FIRSTLINE) &gt;= 15"> indent</xsl:if>
        <xsl:if test="$style/@FONTSTYLE">
          <xsl:text> </xsl:text>
          <xsl:value-of select="$style/@FONTSTYLE"/>
        </xsl:if>
        <xsl:if test="$style/@FONTSIZE">
          <xsl:text> size</xsl:text>
          <xsl:value-of select="$style/@FONTSIZE"/>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="alto:String">
    <xsl:variable name="style">
      <xsl:call-template name="style"/>
    </xsl:variable>
    <!-- Contenu -->
    <xsl:variable name="text">
      <xsl:choose>
        <!-- 2e partie d’une césure -->
        <xsl:when test="@SUBS_TYPE='HypPart2'"/>
        <xsl:when test="@SUBS_CONTENT">
          <xsl:value-of select="@SUBS_CONTENT"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@CONTENT"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$text=''"/>
      <xsl:when test="contains($style, 'superscript')">
        <sup>
          <xsl:value-of select="$text"/>
        </sup>
      </xsl:when>
      <xsl:when test="contains($style,'subscript')">
        <sub>
          <xsl:value-of select="$text"/>
        </sub>
      </xsl:when>
      <xsl:when test="contains($style,'smallcaps')">
        <sc>
          <xsl:value-of select="$text"/>
        </sc>
      </xsl:when>
      <xsl:when test="contains($style,'underline') and contains($style,'italics')">
        <u>
          <i>
            <xsl:value-of select="$text"/>
          </i>
        </u>
      </xsl:when>
      <xsl:when test="contains($style,'italics')">
        <i>
          <xsl:value-of select="$text"/>
        </i>
      </xsl:when>
      <xsl:when test="contains($style,'underline')">
        <u>
          <xsl:value-of select="$text"/>
        </u>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="alto:SP">
    <xsl:text> </xsl:text>
  </xsl:template>
</xsl:transform>
