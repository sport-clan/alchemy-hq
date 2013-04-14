require "hq/xquery/errors"

module HQ
module XQuery
class Session

	def initialize client, session_id
		@client = client
		@session_id = session_id
	end

	def set_library_module module_name, module_text

		request = {
			"name" => "set library module",
			"arguments" => {
				"session id" => @session_id,
				"module name" => module_name,
				"module text" => module_text,
			}
		}

		reply = @client.perform request

		case reply["name"]

			when "ok"
				# do nothing

			else
				raise "Unknown response: #{reply["name"]}"
		end
	end

	def compile_xquery xquery_text, xquery_filename

		request = {
			"name" => "compile xquery",
			"arguments" => {
				"session id" => @session_id,
				"xquery text" => xquery_text,
				"xquery filename" => xquery_filename,
			}
		}

		reply = @client.perform request

		case reply["name"]

			when "ok"

				return reply["arguments"]["result text"]

			when "error"

				arguments = reply["arguments"]

				exception = XQueryError.new
				exception.file = arguments["file"]
				exception.line = arguments["line"]
				exception.column = arguments["column"]
				exception.message = arguments["error"]

				raise exception

			else

				raise "Unknown response: #{reply["name"]}"

		end

	end

	def run_xquery input_text, &callback

		request = {
			"name" => "run xquery",
			"arguments" => {
				"session id" => @session_id,
				"input text" => input_text,
			}
		}

		# make call and process functions

		reply = nil

		loop do

			reply = @client.perform request

			break unless reply["name"] == "function call"

			function_return_values =
				callback.call \
					reply["arguments"]["name"],
					reply["arguments"]["arguments"]

			request = {
				"name" => "function return",
				"arguments" => {
					"values" => function_return_values,
				},
			}

		end

		# process response

		case reply["name"]

			when "ok"
				return reply["arguments"]["result text"]

			when "error"
				arguments = reply["arguments"]
				file = arguments["file"]
				file = "file" if file.empty?
				line = arguments["line"]
				column = arguments["column"]
				error = arguments["error"]
				raise "#{file}:#{line}:#{column} #{error}"

			else
				raise "Unknown response: #{reply["name"]}"
		end

	end

end
end
end
