module Ahq
end

module Ahq::Xquery
end

class Ahq::Xquery::Client

	def initialize url

		@zmq_context = ZMQ::Context.new 1

		@zmq_socket = @zmq_context.socket ZMQ::REQ
		@zmq_socket.connect "tcp://localhost:5555"
	end

	def close

		@zmq_socket.close if @zmq_socket
		@zmq_socket = nil

		@zmq_context.close if @zmq_context
		@zmq_context = nil
	end

	def perform request

		# send request

		request_string = JSON.dump request
		@zmq_socket.send request_string

		# receive reply

		reply_string = @zmq_socket.recv
		return YAML.load reply_string
	end

end
