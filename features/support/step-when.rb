
def zmq_context

	return @zmq_context if @zmq_context

	@zmq_context = ZMQ::Context.new 1

	return @zmq_context

end

When /^I perform the transform$/ do

	# socket

	requester = zmq_context.socket ZMQ::REQ
	requester.connect "tcp://localhost:5555"

	request = {
		"name" => "run xquery",
		"arguments" => {
			"xquery text" => @xquery_text,
			"input text" => @input_text,
		}
	}

	request_string = JSON.dump request

	requester.send request_string

	reply_string = requester.recv

	reply = YAML.load reply_string

	case reply["name"]

		when "ok"

			@result_text = reply["arguments"]["result text"]

		else

			raise "Error"

	end

end
