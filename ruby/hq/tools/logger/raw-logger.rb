require "hq/tools/logger/io-logger"

require "multi_json"

class HQ::Tools::Logger::RawLogger \
	< HQ::Tools::Logger::IoLogger

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
