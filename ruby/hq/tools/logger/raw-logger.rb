require "hq/tools/logger/io-logger"

require "multi_json"

module HQ
module Tools
class Logger
class RawLogger < IoLogger

	def valid_modes
		[ :normal, :partial, :complete ]
	end

	def output_real content, stuff

		data = {
			mode: stuff[:mode],
			content: [ content ],
		}

		data_json = begin
			MultiJson.dump data
		rescue
			out.puts "ERROR encoding #{content} (#{content.encoding})"
		end

		out.print MultiJson.dump(data) + "\n"

	end

end
end
end
end
