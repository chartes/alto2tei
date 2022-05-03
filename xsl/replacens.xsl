<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="1.1" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:param name="old_ns"/>
    <xsl:param name="new_ns"/>
    
    <xsl:template match="@*|node()">        <!-- copy tree -->
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="*" priority="1">   <!-- replace namespace -->
        <xsl:choose>
            <xsl:when test="namespace-uri()=$old_ns">
                <xsl:element name="{name()}" namespace="{$new_ns}">
                    <xsl:apply-templates select="@*|node()"/>
                </xsl:element>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates select="@*|node()"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:transform>
