package mandar;

import java.io.File;
import java.io.Reader;
import java.io.StringReader;
import java.io.StringWriter;
import java.util.HashMap;
import java.util.Map;

import javax.xml.transform.ErrorListener;
import javax.xml.transform.Source;
import javax.xml.transform.TransformerException;
import javax.xml.transform.URIResolver;
import javax.xml.transform.stream.StreamSource;

import lombok.SneakyThrows;
import net.sf.saxon.s9api.DocumentBuilder;
import net.sf.saxon.s9api.Processor;
import net.sf.saxon.s9api.SaxonApiException;
import net.sf.saxon.s9api.Serializer;
import net.sf.saxon.s9api.XQueryCompiler;
import net.sf.saxon.s9api.XQueryEvaluator;
import net.sf.saxon.s9api.XQueryExecutable;
import net.sf.saxon.s9api.XdmNode;
import net.sf.saxon.s9api.XsltCompiler;
import net.sf.saxon.s9api.XsltExecutable;
import net.sf.saxon.s9api.XsltTransformer;

public class ConfigProcessor {

	public final static int INDENT_SPACES = 2;

	Processor processor;
	DocumentBuilder builder;
	URIResolver uriResolver;
	XsltCompiler xsltCompiler;
	XQueryCompiler xqueryCompiler;
	ErrorListener errorListener;

	XdmNode emptyDoc;

	Map<String,XdmNode> documents =
		new HashMap<String,XdmNode> ();
	XsltExecutable xsltExecutable;
	XQueryEvaluator xqueryEvaluator;

	public ConfigProcessor () {
	}

	void init () {

		// processor
		processor = new Processor (false);

		// builder
		builder = processor.newDocumentBuilder ();

		// uri resolver
		uriResolver = new URIResolver () {
			@Override
			public Source resolve (String href, String base)
					throws TransformerException {
				XdmNode doc = documents.get (href);
				return doc.asSource ();
			}
		};

		// compiler
		xsltCompiler = processor.newXsltCompiler ();
		xqueryCompiler = processor.newXQueryCompiler ();

		// empty doc
		try {
			Source emptySource = new StreamSource (new StringReader ("<empty/>"));
			emptyDoc = builder.build (emptySource);
		} catch (SaxonApiException e) {
			throw new RuntimeException ("Unexpected error", e);
		}
	}

	void reset () {
		documents.clear ();
	}

	@SneakyThrows (Exception.class)
	void setDocument (String name, String document) {
		Reader reader = new StringReader (document);
		Source source = new StreamSource (reader);
		XdmNode doc = builder.build (source);
		documents.put (name, doc);
	}

	@SneakyThrows (Exception.class)
	void compileXslt (String path) {
		XdmNode doc = builder.build (new File (path));
		xsltExecutable = xsltCompiler.compile (doc.asSource ());
	}

	@SneakyThrows (Exception.class)
	void compileXquery (String xquerySource) {
		XQueryExecutable executable = xqueryCompiler.compile (xquerySource);
		xqueryEvaluator = executable.load ();
	}

	@SneakyThrows (Exception.class)
	String executeXslt () {

		StringWriter writer = new StringWriter ();

		Serializer serializer = new Serializer ();
		serializer.setOutputProperty (Serializer.Property.METHOD, "xml");
		serializer.setOutputProperty (Serializer.Property.INDENT, "yes");
		serializer.setOutputProperty (Serializer.Property.SAXON_INDENT_SPACES, Integer.toString (INDENT_SPACES));
		serializer.setOutputProperty (Serializer.Property.SAXON_SUPPRESS_INDENTATION, "");
		serializer.setOutputWriter (writer);

		XsltTransformer xsltTransformer = xsltExecutable.load ();
		xsltTransformer.setURIResolver (uriResolver);
		xsltTransformer.setSource (emptyDoc.asSource ());
		xsltTransformer.setDestination (serializer);

		xsltTransformer.transform ();
		writer.write ('\n');

		return writer.toString ();
	}
}
