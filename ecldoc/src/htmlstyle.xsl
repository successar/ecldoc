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
                    IMPORTS
                </h2>
                <xsl:apply-templates select="//Import" mode="desc"/>
                <hr/>
                <h2>
                    <a name="t">Tree</a>
                </h2>
                <xsl:apply-templates select="//Source" mode="tree"/>
                <h2>
                    <a name="d">Description</a>
                </h2>
                <xsl:apply-templates select="//Source" mode="desc"/>
            </body>
        </html>
    </xsl:template>
    <xsl:template match="Source" mode="tree">
        <ul>
            <xsl:apply-templates select="Definition" mode="tree"/>
        </ul>
    </xsl:template>
    <xsl:template match="Import" mode="desc">
        <p>
            IMPORT : <xsl:value-of select="@ref"/>
        </p>
        <p>
            <xsl:element name="a">
                <xsl:attribute name="href"><xsl:value-of select="@target"/></xsl:attribute>
                Link
            </xsl:element>
        </p>
    </xsl:template>
    <xsl:template match="Definition" mode="tree">
        <li>
            <p>
                <xsl:element name="a">
                    <xsl:attribute name="href">#d<xsl:value-of select="@fullname"/></xsl:attribute>
                    <xsl:attribute name="name">t<xsl:value-of select="@fullname"/></xsl:attribute>
                    <xsl:value-of select="Type"/>
                </xsl:element>:
                <xsl:value-of select="Signature"/>
            </p>
            <xsl:if test="Definition">
                <ul>
                    <xsl:apply-templates select="Definition" mode="tree"/>
                </ul>
            </xsl:if>
        </li>
    </xsl:template>
    <xsl:template match="Source" mode="desc">
        <xsl:apply-templates select="//Definition" mode="desc"/>
    </xsl:template>
    <xsl:template match="Definition" mode="desc">
        <hr/>
        <p>
            <xsl:number level="multiple" format="1.1 "/>
            <xsl:element name="a">
                <xsl:attribute name="href">#t<xsl:value-of select="@fullname"/></xsl:attribute>
                <xsl:attribute name="name">d<xsl:value-of select="@fullname"/></xsl:attribute>
                <xsl:value-of select="Type"/>
            </xsl:element>:
            <xsl:value-of select="Signature"/>
            <br/>
            <xsl:if test="Documentation">
                <p>
                    <xsl:value-of select="Documentation/content"/>
                </p>
                <p>@param :
                    <xsl:value-of select="Documentation/param"/>
                </p>
                <p>@return :
                    <xsl:value-of select="Documentation/return"/>
                </p>
            </xsl:if>
        </p>
    </xsl:template>
</xsl:stylesheet>
