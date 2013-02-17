require "hq/tools"

class HQ::Tools::Logger

	MESSAGE_TYPES = [
		:trace,
		:timing,
		:debug,
		:detail,
		:notice,
		:warning,
		:error,
	]

	def initialize
		@targets = []
	end

	def add_target out, format, level

		raise "Invalid log level #{level}" \
			unless MESSAGE_TYPES.include? level.to_sym

		formatter =
			if format.is_a? Class
				format
			else
				case format.to_sym

					when :ansi
						require "hq/tools/logger/ansi-logger"
						HQ::Tools::Logger::AnsiLogger.new

					when :html
						require "hq/tools/logger/html-logger"
						HQ::Tools::Logger::HtmlLogger.new

					when :raw
						require "hq/tools/logger/raw-logger"
						HQ::Tools::Logger::RawLogger.new

					when :text
						require "hq/tools/logger/text-logger"
						HQ::Tools::Logger::TextLogger.new

					else
						raise "Error"

				end
			end

		formatter.out = out

		@targets << {
			formatter: formatter,
			level: level.to_sym,
		}

	end

	def level_includes level_1, level_2

		index_1 =
			MESSAGE_TYPES.index(level_1.to_sym)

		index_2 =
			MESSAGE_TYPES.index(level_2.to_sym)

		return index_1 <= index_2

	end

	def output content, mode = :normal

		raise "Must provide hostname" \
			unless content["hostname"]

		@targets.each do
			|target|

			next unless level_includes \
				target[:level],
				content["level"].to_sym

			stuff = {
				out: target[:out],
				mode: mode,
			}

			next unless target[:formatter].valid_modes.include? mode

			target[:formatter].output content, stuff

		end

	end

	def message text, level, *content

		output({
			"type" => "log",
			"hostname" => Mandar.host,
			"level" => level,
			"text" => text,
			"content" => content,
		})

	end

	def message_partial text, level, *content

		output({
			"type" => "log",
			"level" => level,
			"text" => text,
			"content" => content
		}, :partial)

	end

	def message_complete text, level, *content

		output({
			"type" => "log",
			"level" => level,
			"text" => text,
			"content" => content
		}, :complete)

	end

end
