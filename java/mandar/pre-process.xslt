<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" omit-xml-declaration="no"/>

	<!-- identity template -->
	<xsl:template match="/*">
		<xsl:element name="xsl:stylesheet">
			<xsl:attribute name="version" select="@xsl:version"/>
			<xsl:copy-of select="xsl:function|xsl:variable"/>
			<xsl:element name="xsl:template">
				<xsl:attribute name="match">/</xsl:attribute>
				<xsl:copy>
					<xsl:apply-templates select="@*|node()"/>
				</xsl:copy>
			</xsl:element>
		</xsl:element>
	</xsl:template>

	<!-- ignore top level xsl stuff -->
	<xsl:template match="xsl:function|xsl:variable">
	</xsl:template>

	<!-- copy all by default -->
	<xsl:template match="@*|node()">
		<xsl:copy-of select="."/>
	</xsl:template>

</xsl:stylesheet>