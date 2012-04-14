def zmq_context

	return @zmq_context if @zmq_context

	# create context

	@zmq_context = ZMQ::Context.new 1

	return @zmq_context

end

def zmq_socket

	return @zmq_socket if @zmq_socket

	# connect socket

	@zmq_socket = zmq_context.socket ZMQ::REQ
	@zmq_socket.connect "tcp://localhost:5555"

	return @zmq_socket

end

def zmq_perform request

	# send request

	request_string = JSON.dump request
	zmq_socket.send request_string

	# receive reply

	reply_string = @zmq_socket.recv
	return YAML.load reply_string

end

After do

	# close zmq socket and context

	@zmq_socket.close if @zmq_socket
	@zmq_context.close if @zmq_context

end
