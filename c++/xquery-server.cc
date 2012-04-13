
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

// zero mq library

#include <zmq.hpp>

using namespace std;

void run_xquery (
		zmq::socket_t & socket,
		string xquery_text,
		string input_text) {

	// perform query

	XQilla xqilla;

	string result_text;

	try {

		AutoDelete<XQQuery> query (
			xqilla.parse (X (xquery_text.c_str ())));

		AutoDelete<DynamicContext> context (
			query->createDynamicContext ());

		xercesc::MemBufInputSource input_source (
			(XMLByte *) input_text.data (),
			input_text.size (),
			X ("input.xml"));

		Node::Ptr input_document =
			context->parseDocument (
				input_source);

		context->setContextItem (input_document);

		context->setContextPosition (1);

		context->setContextSize (1);

		Result result =
			query->execute (context);

		ostringstream result_stream;

		while (Item::Ptr item = result->next (context)) {
			result_stream << UTF8 (item->asString (context));
		}

		result_text = result_stream.str ();

	} catch (XQException & error) {

		cout << UTF8 (error.getError ()) << "\n";

		exit (1);
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

		string xquery_text =
			arguments ["xquery text"].asString ();

		string input_text =
			arguments ["input text"].asString ();

		run_xquery (socket, xquery_text, input_text);

	} else {

		cout << "Invalid function name: " << name << "\n";

		exit (1);

	}
}

int main () {
 
    // setup

    zmq::context_t context (1);
    zmq::socket_t socket (context, ZMQ_REP);

    socket.bind ("tcp://*:5555");

	cout << "Running\n";

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
