
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

	Session () {
	}

	virtual ~Session () {
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
			return false;

		string module_text =
			modules [system_id];

		return new xercesc::MemBufInputSource (
			(XMLByte *) module_text.data (),
			module_text.size (),
			resource_id->getSystemId ());
	}
};

map <string, Session *> sessions;

Session * get_session (string session_id) {

	Session * session =
		sessions [session_id];

	if (session != NULL)
		return session;

	return sessions [session_id] =
		new Session ();
}

void run_xquery (
		zmq::socket_t & socket,
		string session_id,
		string xquery_text,
		string input_text) {

	Session * session =
		get_session (session_id);

	// perform query

	string result_text;

	try {

		AutoDelete<DynamicContext> static_context (
			xqilla.createContext ());

		static_context->setModuleResolver (
			session);

		DocumentCache * documentCache =
			static_context->getDocumentCache ();

		documentCache->setXMLEntityResolver (session);

		AutoDelete<XQQuery> query (
			xqilla.parse (
				X (xquery_text.c_str ()),
				static_context.adopt ()));

		xercesc::MemBufInputSource input_source (
			(XMLByte *) input_text.data (),
			input_text.size (),
			X ("input.xml"));

		AutoDelete<DynamicContext> dynamic_context (
			query->createDynamicContext ());

		Node::Ptr input_document =
			dynamic_context->parseDocument (
				input_source);

		dynamic_context->setContextItem (input_document);
		dynamic_context->setContextPosition (1);
		dynamic_context->setContextSize (1);

		Result result =
			query->execute (dynamic_context);

		ostringstream result_stream;

		while (Item::Ptr item = result->next (dynamic_context)) {
			result_stream << UTF8 (item->asString (dynamic_context));
		}

		result_text = result_stream.str ();

	} catch (XQException & error) {

		cout << UTF8 (error.getError ()) << "\n";

		// send reply

		Json::FastWriter writer;

		Json::Value root (Json::objectValue);

		root ["name"] =
			"error";

		root ["arguments"] =
			Json::Value (Json::objectValue);

		root ["arguments"] ["type"] =
			UTF8 (error.getType ());

		root ["arguments"] ["error"] =
			UTF8 (error.getError ());

		root ["arguments"] ["file"] =
			UTF8 (error.getXQueryFile ());

		root ["arguments"] ["line"] =
			error.getXQueryLine ();

		root ["arguments"] ["column"] =
			error.getXQueryColumn ();

		string reply_text =
			writer.write (root);

		zmq::message_t reply (reply_text.size ());

		memcpy (reply.data (), reply_text.data (), reply_text.size ());

		socket.send (reply);

		return;
	}

	// send reply

	Json::FastWriter writer;

	Json::Value root (Json::objectValue);

	root ["name"] =
		"ok";

	root ["arguments"] =
		Json::Value (Json::objectValue);

	root ["arguments"] ["result text"] =
		result_text;

	string reply_text =
		writer.write (root);

	zmq::message_t reply (reply_text.size ());

	memcpy (reply.data (), reply_text.data (), reply_text.size ());

	socket.send (reply);
}

void set_library_module (
		zmq::socket_t & socket,
		string session_id,
		string module_name,
		string module_text) {

	Session * session =
		get_session (session_id);

	// set module

	session->modules [module_name] =
		module_text;

	// send reply

	Json::FastWriter writer;

	Json::Value root (Json::objectValue);

	root ["name"] =
		"ok";

	root ["arguments"] =
		Json::Value (Json::objectValue);

	string reply_text =
		writer.write (root);

	zmq::message_t reply (reply_text.size ());

	memcpy (reply.data (), reply_text.data (), reply_text.size ());

	socket.send (reply);
}

void handle_request (
		zmq::socket_t & socket,
		string request_string) {

	// decode

	Json::Value root;

	Json::Reader reader;

	bool parsingSuccessful =
		reader.parse (request_string, root);

	if (! parsingSuccessful) {

		std::cout << "Failed to parse request\n"
			<< reader.getFormattedErrorMessages ();

		exit (1);
	}

	// lookup function

	string name =
		root ["name"].asString ();

	Json::Value arguments =
		root ["arguments"];

	if (name == "run xquery") {

		run_xquery (
			socket,
			arguments ["session id"].asString (),
			arguments ["xquery text"].asString (),
			arguments ["input text"].asString ());

	} else if (name == "set library module") {

		set_library_module (
			socket,
			arguments ["session id"].asString (),
			arguments ["module name"].asString (),
			arguments ["module text"].asString ());

	} else {

		cout << "Invalid function name: " << name << "\n";

		exit (1);

	}
}

int main (int argc, char * argv []) {

	if (argc != 2) {
		cout << "Syntax error\n";
		return 1;
	}

    // setup

    zmq::context_t context (1);
    zmq::socket_t socket (context, ZMQ_REP);

    socket.bind (argv [1]);

	cout << "Ready\n";

    while (true) {

        zmq::message_t request;

        // get request

        socket.recv (& request);

		string request_string =
			string (
				(const char *) request.data (),
				request.size ());

		handle_request (socket, request_string);
    }

    return 0;
}
