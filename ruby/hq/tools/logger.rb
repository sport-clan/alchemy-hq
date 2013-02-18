require "hq/tools"

class HQ::Tools::Logger

	attr_accessor :hostname

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

	def message text, level, *content
		message text, level, *content
	end

	def message_partial text, level, *content
		message_partial text, level, options
	end

	def message_complete text, level, *content
		message_complete text, level, options
	end

	def trace text, *contents
		message text, :trace, *contents
	end

	def timing text, *contents
		message text, :timing, *contents
	end

	def debug text, *contents
		message text, :debug, *contents
	end

	def detail text, *contents
		message text, :detail, *contents
	end

	def notice text, *contents
		message text, :notice, *contents
	end

	def warning text, *contents
		message text, :warning, *contents
	end

	def error text, *contents
		message text, :error, *contents
	end

	def time text, level = :timing

		time_start =
			Time.now

		begin

			yield

		ensure

			time_end =
				Time.now

			timing_ms =
				((time_end - time_start) * 1000).to_i

			timing_str =
				case timing_ms
					when (0...1000)
						"%dms" % [ timing_ms ]
					when (1000...10000)
						"%.2fs" % [ timing_ms.to_f / 1000 ]
					when (10000...100000)
						"%.1fs" % [ timing_ms.to_f / 1000 ]
					else
						"%ds" % [ timing_ms / 1000 ]
				end

			message \
				"#{text} took #{timing_str}",
				level

		end

	end

	def die text, status = 1
		error text
		exit status
	end

	def add_auto str

		level, format, filename =
			str.split ":", 3

		add_target \
			filename ? File.open(filename, "a") : STDOUT,
			format || :ansi,
			level || hq_config["default-log-level"] || :detail

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
			"hostname" => hostname,
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
