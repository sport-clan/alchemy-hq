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

		require "hq/tools/logger/multi-logger"

		@multi_logger =
			HQ::Tools::Logger::MultiLogger.new

	end

	def add_target out, format, level

		raise "Invalid log level #{level}" \
			unless MESSAGE_TYPES.include? level.to_sym

		logger =
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

		logger.out = out
		logger.level = level

		@multi_logger.add_logger logger

	end

	def self.level_includes level_1, level_2

		index_1 =
			MESSAGE_TYPES.index(level_1.to_sym)

		index_2 =
			MESSAGE_TYPES.index(level_2.to_sym)

		return index_1 <= index_2

	end

	def output content, mode = :normal

		raise "Must provide hostname" \
			unless content["hostname"]

		@multi_logger.output \
			content,
			{ mode: mode }

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
