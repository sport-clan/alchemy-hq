require "hq/tools/logger/io-logger"

require "multi_json"

module HQ
module Tools
class Logger
class RawLogger < IoLogger

	def valid_modes
		[ :normal, :partial ]
	end

	def output_real content, stuff

		data = {
			mode: stuff[:mode],
			content: [ content ],
		}

		out.print MultiJson.dump(data) + "\n"

	end

end
end
end
end
