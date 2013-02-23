module Mandar
module Console
class ConsoleWebSocketHandler

	include Utils

	attr_accessor :app_ctx

	def handle_errors message

		begin

			yield

		rescue Exception => exception

			$stderr.puts \
				message,
				exception.message,
				*exception.backtrace

		ensure


		end

	end

	def handle web_socket

		handler = nil

puts "A"
		web_socket.onopen do
			|handshake|
puts "B"

			handle_errors "Error handling web socket open" do

				case handshake.path

				when "/deploy-progress"
					require "mandar/console/deploy-progress-handler"
					handler = DeployProgressHandler.new
					handler.app_ctx = app_ctx
					handler.web_socket = web_socket
					handler.open handshake

				else
					puts "WEB SOCKET: Invalid path: #{handshake.path}"

				end

			end

		end

		web_socket.onclose do
puts "C"

			handle_errors "Error handling web socket close" do
				handler.close if handler
			end

		end

		web_socket.onmessage do |message|
puts "D"

			handle_errors "Error handling web socket message" do
				handler.message message if handler
			end

		end

		web_socket.onerror do |error|
puts "E"

			handle_errors "Error handling web socket error" do
				handler.error error if handler
			end

		end

	end

end
end
end
