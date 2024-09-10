<xsl:stylesheet
     xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     xmlns:r="http://exist-db.org/xquery/repo"
     xmlns:p="http://expath.org/ns/pkg"
     exclude-result-prefixes="r p"
    version="1.0">

  <xsl:strip-space elements="*" />
  <xsl:output method="xml" indent="yes"/>
 <xsl:param name="version" select="''" />
 <xsl:variable name="version-text">
   <xsl:choose>
     <xsl:when test="$version = ''"></xsl:when>
     <xsl:otherwise><xsl:value-of select="concat('-', $version)"/></xsl:otherwise>
   </xsl:choose>
 </xsl:variable>
 <xsl:strip-space elements="*"/>


 <xsl:template match="r:meta/r:description | r:meta/r:target | p:package/p:title" priority="2">
 <xsl:copy>
   <xsl:value-of select="concat(., $version-text)" />
 </xsl:copy>
</xsl:template>

 <xsl:template match="p:package/@name | p:package/@abbrev" priority="2">
   <xsl:attribute name="{name()}">
     <xsl:value-of select="concat(., $version-text)" />
   </xsl:attribute>
</xsl:template>

 
 <xsl:template match="node() | @*">
  <xsl:copy>
   <xsl:apply-templates select="node() | @*"/>
  </xsl:copy>
 </xsl:template>
 
 <xsl:template match="comment()" priority="2" />
 
 
</xsl:stylesheet>