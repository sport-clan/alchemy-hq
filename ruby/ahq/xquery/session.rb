module Ahq
end

module Ahq::Xquery
end

class Ahq::Xquery::Session

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

	def run_xquery xquery_text, input_text

		request = {
			"name" => "run xquery",
			"arguments" => {
				"session id" => @session_id,
				"xquery text" => xquery_text,
				"input text" => input_text,
			}
		}

		reply = @client.perform request

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
