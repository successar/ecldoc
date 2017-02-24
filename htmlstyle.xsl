<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="/">
    <html>
      <head>
        <title>example</title>
      </head>
      <body>
        <h2>
          <a name="t">Tree</a>
        </h2>
        <xsl:apply-templates mode="tree"/>
        <h2>
          <a name="d">Description</a>
        </h2>
        <xsl:apply-templates mode="desc"/>
      </body>
    </html>
  </xsl:template>
  <xsl:template match="EXPORTS" mode="tree">
    <ul>
      <xsl:apply-templates mode="tree"/>
    </ul>
  </xsl:template>
  <xsl:template match="EXPORT" mode="tree">
    <li>
      <p>
        <xsl:number level="multiple" format="1.1 "/>
        <xsl:element name="a">
          <xsl:attribute name="href">#d<xsl:number level="multiple" format="1.1"/></xsl:attribute>
          <xsl:attribute name="name">t<xsl:number level="multiple" format="1.1"/></xsl:attribute>
          <xsl:value-of select="START|ATTR"/>
        </xsl:element>: 
        <xsl:value-of select="ARGS"/>
      </p>
      <xsl:apply-templates mode="tree"/>
    </li>
  </xsl:template>
  <xsl:template match="text()" mode="tree"/>
  <xsl:template match="EXPORTS" mode="desc">
    <xsl:apply-templates mode="desc"/>
  </xsl:template>
  <xsl:template match="EXPORT" mode="desc">
    <hr/>
    <p>
      <xsl:number level="multiple" format="1.1 "/>
      <xsl:element name="a">
        <xsl:attribute name="href">#t<xsl:number level="multiple" format="1.1"/></xsl:attribute>
        <xsl:attribute name="name">d<xsl:number level="multiple" format="1.1"/></xsl:attribute>
        <xsl:value-of select="START|ATTR"/>
      </xsl:element>: 
      <xsl:value-of select="ARGS"/>
    </p>
    <p>
      <xsl:variable name="id">
        <xsl:number level="multiple" format="1.1 "/>
      </xsl:variable>See 
      <xsl:element name="a">
        <xsl:attribute name="href">#d<xsl:call-template name="substring-before-last">
            <xsl:with-param name="string1" select="$id" />
            <xsl:with-param name="string2" select="'.'" />
          </xsl:call-template>
        </xsl:attribute> 
        Parent
      </xsl:element>
    </p>
    <xsl:apply-templates mode="desc"/>
  </xsl:template>
  <xsl:template match="COMMENT" mode="desc">
    <p>
      <xsl:value-of select="DESC"/>
    </p>
    <p>@param : 
      <xsl:value-of select="PARAM"/>
    </p>
    <p>@return : 
      <xsl:value-of select="RETURN"/>
    </p>
  </xsl:template>
  <xsl:template match="text()" mode="desc"/>
  <xsl:template name="substring-before-last">
    <xsl:param name="string1" select="''" />
    <xsl:param name="string2" select="''" />
    <xsl:if test="$string1 != '' and $string2 != ''">
      <xsl:variable name="head" select="substring-before($string1, $string2)" />
      <xsl:variable name="tail" select="substring-after($string1, $string2)" />
      <xsl:value-of select="$head" />
      <xsl:if test="contains($tail, $string2)">
        <xsl:value-of select="$string2" />
        <xsl:call-template name="substring-before-last">
          <xsl:with-param name="string1" select="$tail" />
          <xsl:with-param name="string2" select="$string2" />
        </xsl:call-template>
      </xsl:if>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>