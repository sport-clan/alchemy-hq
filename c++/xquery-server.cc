
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

struct CallbackFunction :
	public ExternalFunction {

	CallbackFunction (const char * name, int args, XPath2MemoryManager * mm)
		: ExternalFunction (X ("hq"), X (name), args, mm) {
	}

	virtual void setupFuncCall (
			Json::Value & func_call,
			const Arguments * args,
			DynamicContext * context
		) const = 0;

	virtual Result execute (
			const Arguments * args,
			DynamicContext * context) const {

		// send function call

		Json::Value func_call (Json::objectValue);

		func_call["name"] = "function call";
		func_call["arguments"] = Json::objectValue;

		setupFuncCall (func_call, args, context);

		Json::FastWriter writer;
		string func_call_str = writer.write (func_call);
		cout << func_call_str.size () << "\n" << func_call_str;

		ItemFactory * itemFactory =
			context->getItemFactory ();

		// read function response

		int func_return_len;
		cin >> func_return_len;

		char func_return_buf [func_return_len];
		cin.read (func_return_buf, func_return_len);
		string func_return_str (func_return_buf, func_return_len);

		Json::Value func_return;
		Json::Reader reader;

		bool parsingSuccessful =
			reader.parse (func_return_str, func_return);

		if (! parsingSuccessful) {

			cerr << "Failed to parse request\n"
				<< reader.getFormattedErrorMessages ();

			exit (1);
		}

		// return as sequence

		Json::Value values =
			func_return["arguments"]["values"];

		Sequence return_sequence;

		for (int i = 0; i < values.size (); i++) {

			string value_str = values[i].asString ();

			xercesc::MemBufInputSource input_source (
				(XMLByte *) value_str.c_str (),
				value_str.size (),
				X ("value.xml"));

			Node::Ptr value_document =
				context->parseDocument (
					input_source);

			Result result =
				value_document->dmChildren (context, NULL);

			Item::Ptr item =
				result->next (context);

			return_sequence.addItem (item);

		}

		return return_sequence;

	}

};

struct GetByIdFunction :
	public CallbackFunction {

	GetByIdFunction (XPath2MemoryManager * mm)
		: CallbackFunction ("get", 1, mm) {
	}

	void setupFuncCall (
			Json::Value & func_call,
			const Arguments * args,
			DynamicContext * context) const {

		func_call["arguments"]["name"] = "get record by id";
		func_call["arguments"]["arguments"] = Json::objectValue;

		Result result =
			args->getArgument (0, context);

		Item::Ptr item =
			result->next (context);

		func_call["arguments"]["arguments"]["id"] =
			UTF8 (item->asString (context));

	}

};

struct GetByIdPartsFunction :
	public CallbackFunction {

	GetByIdPartsFunction (XPath2MemoryManager * mm)
		: CallbackFunction ("get", 2, mm) {
	}

	void setupFuncCall (
			Json::Value & func_call,
			const Arguments * args,
			DynamicContext * context) const {

		func_call["arguments"]["name"] = "get record by id parts";
		func_call["arguments"]["arguments"] = Json::objectValue;

		Result result =
			args->getArgument (0, context);

		Item::Ptr item =
			result->next (context);

		func_call["arguments"]["arguments"]["type"] =
			UTF8 (item->asString (context));

		// add id parts

		Json::Value & id_parts_json =
			func_call["arguments"]["arguments"]["id parts"];

		id_parts_json =
			Json::arrayValue;

		Result id_parts_result =
			args->getArgument (1, context);

		while (
			Item::Ptr id_part_item =
				id_parts_result->next (context)
		) {

			id_parts_json.append (
				UTF8 (id_part_item->asString (context)));

		}

	}

};

struct FindByTypeFunction :
	public CallbackFunction {

	FindByTypeFunction (XPath2MemoryManager * mm)
		: CallbackFunction ("find", 1, mm) {
	}

	void setupFuncCall (
			Json::Value & func_call,
			const Arguments * args,
			DynamicContext * context) const {

		func_call["arguments"]["name"] = "search records";
		func_call["arguments"]["arguments"] = Json::objectValue;

		Result result =
			args->getArgument (0, context);

		Item::Ptr item =
			result->next (context);

		func_call["arguments"]["arguments"]["type"] =
			UTF8 (item->asString (context));

	}

};

struct FindByTypeCriteriaFunction :
	public CallbackFunction {

	FindByTypeCriteriaFunction (XPath2MemoryManager * mm)
		: CallbackFunction ("find", 2, mm) {
	}

	void setupFuncCall (
			Json::Value & func_call,
			const Arguments * args,
			DynamicContext * context) const {

		func_call["arguments"]["name"] = "search records";
		func_call["arguments"]["arguments"] = Json::objectValue;

		Result result =
			args->getArgument (0, context);

		Item::Ptr item =
			result->next (context);

		func_call["arguments"]["arguments"]["type"] =
			UTF8 (item->asString (context));

		// add criteria

		Json::Value & criteria_json =
			func_call["arguments"]["arguments"]["criteria"];

		criteria_json =
			Json::objectValue;

		Result criteria_result =
			args->getArgument (1, context);

		while (
			Item::Ptr criteria_item =
				criteria_result->next (context)
		) {

			string criteria_str =
				UTF8 (criteria_item->asString (context));

			int pos =
				criteria_str.find ('=');

			if (pos == string::npos) {
				cerr << "ERROR 64168123\n";
				exit (1);
			}

			string criteria_key_str =
				criteria_str.substr (0, pos);

			string criteria_value_str =
				criteria_str.substr (pos + 1);

			criteria_json[criteria_key_str] =
				criteria_value_str;

		}

	}

};

struct MyFunctionResolver :
	public ExternalFunctionResolver {

public:

	virtual ExternalFunction * resolveExternalFunction (
		const XMLCh * uri_xmlch,
		const XMLCh * name_xmlch,
		size_t numArgs,
		const StaticContext * context) {

		string uri = UTF8 (uri_xmlch);
		string name = UTF8 (name_xmlch);

		if (uri != "hq")
			return NULL;

		XPath2MemoryManager * mm (context->getMemoryManager ());

		if (name == "get") {

			if (numArgs == 1)
				return new GetByIdFunction (mm);

			if (numArgs == 2)
				return new GetByIdPartsFunction (mm);

		}

		if (name == "get" && numArgs == 1)
			return new GetByIdFunction (mm);

		if (name == "find") {

			if (numArgs == 1)
				return new FindByTypeFunction (mm);

			if (numArgs == 2)
				return new FindByTypeCriteriaFunction (mm);

		}

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

		// set function resolver

		MyFunctionResolver * myFuncResolver =
			new MyFunctionResolver;

		static_context->setExternalFunctionResolver (
			myFuncResolver);

		// parse query

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
