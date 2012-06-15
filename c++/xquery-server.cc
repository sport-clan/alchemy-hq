
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

// xerces library

#include <xercesc/framework/MemBufInputSource.hpp>
#include <xercesc/util/XMLEntityResolver.hpp>

// zero mq library

#include <zmq.hpp>

using namespace std;

XQilla xqilla;

struct Session :
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

		static_context->setModuleResolver (& session);

		DocumentCache * documentCache =
			static_context->getDocumentCache ();

		documentCache->setXMLEntityResolver (& session);

		AutoDelete<XQQuery> query (
			xqilla.parse (
				X (xquery_text.c_str ()),
				static_context.adopt ()));

		session.set_query (query.adopt ());

	} catch (XQException & error) {

		cout << UTF8 (error.getError ()) << "\n";

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

		cout << UTF8 (error.getError ()) << "\n";

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

		std::cout << "Failed to parse request\n"
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

		cout << "Invalid function name: " << request_name << "\n";

		exit (1);
	}

	// send reply

	Json::FastWriter writer;

	return writer.write (reply);
}

int main (int argc, char * argv []) {

	if (argc != 2) {
		cout << "Syntax error\n";
		return EXIT_FAILURE;
	}

	// setup

	zmq::context_t context (1);
	zmq::socket_t socket (context, ZMQ_REP);

	socket.bind (argv [1]);

	cout << "Ready\n";

	while (true) {

		// get request

		zmq::message_t request;

		socket.recv (& request);

		string request_string (
			(const char *) request.data (),
			request.size ());

		// handle

		string reply_string =
			handle_request (
				request_string);

		// send reply

		zmq::message_t reply (reply_string.size ());

		memcpy (
			reply.data (),
			reply_string.data (),
			reply_string.size ());

		socket.send (reply);
	}

	return EXIT_SUCCESS;
}
