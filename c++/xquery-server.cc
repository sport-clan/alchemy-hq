
// c++ libraries

#include <iostream>
#include <sstream>
#include <string>

// c libraries

#include <stdlib.h>
#include <unistd.h>

// json library

#include <jsoncpp/json/json.h>

// xqilla xquery library

#include <xqilla/xqilla-simple.hpp>

#include <xqilla/context/ExternalFunctionResolver.hpp>
#include <xqilla/functions/ExternalFunction.hpp>
#include <xqilla/update/PendingUpdateList.hpp>

// xerces library

#include <xercesc/framework/MemBufInputSource.hpp>
#include <xercesc/util/XMLEntityResolver.hpp>

using namespace std;

XQilla xqilla;

struct Session :
	public MessageListener,
	public ModuleResolver,
	public xercesc::XMLEntityResolver {

	map<string,string> modules;

	XQQuery * query;

	Session () {

		query = NULL;
	}

	virtual ~Session () {

		if (query)
			delete query;
	}

	void set_query (XQQuery * query) {

		if (this->query)
			delete this->query;

		this->query = query;
	}

	virtual bool resolveModuleLocation (
			VectorOfStrings * result,
			const XMLCh * uri_xmlch,
			const StaticContext * context) {

		result->push_back (uri_xmlch);

		return true;
	}

	virtual xercesc::InputSource * resolveEntity (
			xercesc::XMLResourceIdentifier * resource_id) {

		string system_id =
			UTF8 (resource_id->getSystemId ());

		if (! modules.count (system_id))
			return NULL;

		string module_text =
			modules [system_id];

		return new xercesc::MemBufInputSource (
			(XMLByte *) module_text.data (),
			module_text.size (),
			resource_id->getSystemId ());
	}

	virtual void warning (
			const XMLCh * message,
			const LocationInfo * location) {

		cerr << "WARN: " << UTF8 (message) << "\n";
	}

	virtual void trace (
			const XMLCh * label,
			const Sequence & sequence,
			const LocationInfo * location,
			const DynamicContext * context) {

		cerr << "TRACE: " << UTF8 (label) << "\n";
	}
};

struct MyFunction :
	public ExternalFunction {

	MyFunction (XPath2MemoryManager * mm)
		: ExternalFunction (X ("hq"), X ("test"), 0, mm) {
	}

	virtual Result execute (
			const Arguments * args,
			DynamicContext * context) const {

		ItemFactory * itemFactory =
			context->getItemFactory ();

		return Result (
			itemFactory->createString (
				X ("hello world"),
				context));

	}

};

struct MyFunctionResolver :
	public ExternalFunctionResolver {

	virtual ExternalFunction * resolveExternalFunction (
		const XMLCh * uri_xmlch,
		const XMLCh * name_xmlch,
		size_t numArgs,
		const StaticContext * context) {

		string uri = UTF8 (uri_xmlch);
		string name = UTF8 (name_xmlch);

		cerr << "RESOLVE " << uri << "/" << name << "/" << numArgs << "\n";

		if (uri != "hq")
			return NULL;

		if (name == "test")
			return new MyFunction (context->getMemoryManager ());

		return NULL;

	}

};

map <string, Session *> sessions;

Session & get_session (string session_id) {

	Session * session =
		sessions [session_id];

	if (session != NULL)
		return * session;

	session = new Session ();

	sessions [session_id] =
		session;

	return * session;
}

void set_error (
		Json::Value & reply,
		XQException & error) {

	reply ["name"] =
		"error";

	reply ["arguments"] ["type"] =
		UTF8 (error.getType ());

	reply ["arguments"] ["error"] =
		UTF8 (error.getError ());

	reply ["arguments"] ["file"] =
		UTF8 (error.getXQueryFile ());

	reply ["arguments"] ["line"] =
		error.getXQueryLine ();

	reply ["arguments"] ["column"] =
		error.getXQueryColumn ();
}

void compile_xquery (
		Json::Value & reply,
		string session_id,
		string xquery_text) {

	Session & session =
		get_session (session_id);

	try {

		AutoDelete<DynamicContext> static_context (
			xqilla.createContext ());

		static_context->setProjection (false);

		static_context->setMessageListener (& session);

		static_context->setModuleResolver (& session);

		DocumentCache * documentCache =
			static_context->getDocumentCache ();

		documentCache->setXMLEntityResolver (& session);

MyFunctionResolver myFuncResolver;

static_context->setExternalFunctionResolver (& myFuncResolver);

MyFunction myFunc (static_context->getMemoryManager ());
static_context->addExternalFunction (& myFunc);

//const ExternalFunctionResolver * temp1 =
//	static_context->getExternalFunctionResolver ();
//cerr << "it is " << (temp1 ? "yes" : "no") << "\n";

//const ExternalFunction * temp =
//	static_context->lookUpExternalFunction (X ("hq"), X ("test"), 0);
//cerr << "it is " << (temp ? "yes" : "no") << "\n";

		AutoDelete<XQQuery> query (
			xqilla.parse (
				X (xquery_text.c_str ()),
				static_context.adopt ()));

		session.set_query (query.adopt ());

	} catch (XQException & error) {

		cerr << UTF8 (error.getError ()) << "\n";

		set_error (reply, error);

		return;
	}

	// send reply

	reply ["name"] =
		"ok";
}

void run_xquery (
		Json::Value & reply,
		string session_id,
		string input_text) {

	Session & session =
		get_session (session_id);

	// fail if there is no query

	if (! session.query) {

		reply ["name"] =
			"usage error";

		return;
	}

	// perform query

	string result_text;

	try {

		xercesc::MemBufInputSource input_source (
			(XMLByte *) input_text.data (),
			input_text.size (),
			X ("input.xml"));

		AutoDelete<DynamicContext> dynamic_context (
			session.query->createDynamicContext ());

		Node::Ptr input_document =
			dynamic_context->parseDocument (
				input_source);

		dynamic_context->setContextItem (input_document);
		dynamic_context->setContextPosition (1);
		dynamic_context->setContextSize (1);

		Result result =
			session.query->execute (dynamic_context);

		ostringstream result_stream;

		while (Item::Ptr item = result->next (dynamic_context)) {
			result_stream << UTF8 (item->asString (dynamic_context));
		}

		result_text = result_stream.str ();

	} catch (XQException & error) {

		cerr << UTF8 (error.getError ()) << "\n";

		set_error (reply, error);

		return;
	}

	// send reply

	reply ["name"] =
		"ok";

	reply ["arguments"] ["result text"] =
		result_text;
}

void set_library_module (
		Json::Value & reply,
		string session_id,
		string module_name,
		string module_text) {

	Session & session =
		get_session (session_id);

	// set module

	session.modules [module_name] =
		module_text;

	// send reply

	reply ["name"] =
		"ok";
}

string handle_request (
		string request_string) {

	// decode

	Json::Value request;

	Json::Reader reader;

	bool parsingSuccessful =
		reader.parse (request_string, request);

	if (! parsingSuccessful) {

		cerr << "Failed to parse request\n"
			<< reader.getFormattedErrorMessages ();

		exit (1);
	}

	// lookup function

	string request_name =
		request ["name"].asString ();

	Json::Value request_arguments =
		request ["arguments"];

	Json::Value reply (Json::objectValue);

	reply ["arguments"] =
		Json::Value (Json::objectValue);

	if (request_name == "compile xquery") {

		compile_xquery (
			reply,
			request_arguments ["session id"].asString (),
			request_arguments ["xquery text"].asString ());

	} else if (request_name == "run xquery") {

		run_xquery (
			reply,
			request_arguments ["session id"].asString (),
			request_arguments ["input text"].asString ());

	} else if (request_name == "set library module") {

		set_library_module (
			reply,
			request_arguments ["session id"].asString (),
			request_arguments ["module name"].asString (),
			request_arguments ["module text"].asString ());

	} else {

		cerr << "Invalid function name: " << request_name << "\n";

		exit (1);
	}

	// send reply

	Json::FastWriter writer;

	return writer.write (reply);
}

int main (int argc, char * argv []) {

	while (true) {

		// read request

		int request_len;
		cin >> request_len;

		char request_buf [request_len];
		cin.read (request_buf, request_len);
		string request_string (request_buf, request_len);

		// handle

		string reply_string =
			handle_request (request_string);

		// send reply

		cout << reply_string.size () << "\n";

		cout << reply_string;
	}

	return EXIT_SUCCESS;
}
