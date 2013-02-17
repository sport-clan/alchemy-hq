require "hq/tools/logger/formatter"

require "multi_json"

class HQ::Tools::Logger::RawFormatter \
	< HQ::Tools::Logger::Formatter

	def valid_modes
		[ :normal, :partial ]
	end

	def output content, stuff

		data = {
			mode: stuff[:mode],
			content: [ content ],
		}

		stuff[:out].print MultiJson.dump(data) + "\n"

	end

end
