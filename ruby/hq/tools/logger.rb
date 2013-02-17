require "multi_json"

require "hq/tools"

require "hq/tools/escape"

class HQ::Tools::Logger

	include HQ::Tools::Escape

	DIFF_COLOURS = {
		:minus_minus_minus => :magenta,
		:plus_plus_plus => :magenta,
		:at_at => :magenta,
		:minus => :red,
		:plus => :blue,
		:else => :white,
	}

	ANSI_CODES = {
		:normal => "\e[0m",
		:bold => "\e[1m",
		:black => "\e[30m",
		:red => "\e[31m",
		:green => "\e[32m",
		:yellow => "\e[33m",
		:blue => "\e[34m",
		:magenta => "\e[35m",
		:cyan => "\e[36m",
		:white => "\e[37m",
	}

	MESSAGE_TYPES = [
		:trace,
		:timing,
		:debug,
		:detail,
		:notice,
		:warning,
		:error,
	]

	MESSAGE_COLOURS = {

		:normal => :normal,

		:hostname => :blue,

		:trace => :magenta,
		:debug => :cyan,
		:detail => :white,
		:notice => :green,
		:warning => :yellow,
		:error => :red,

		:command_output => :white,
	}

	def initialize
		@targets = []
	end

	def add_target out, format, level

		raise "Invalid log level #{level}" \
			unless MESSAGE_TYPES.include? level.to_sym

		@targets << {
			out: out,
			format: format.to_sym,
			level: level.to_sym,
		}

	end

	def fix_stuff old_stuff, content, prefix = nil

		content = {} \
			unless content.is_a? Hash

		new_stuff = {
			out: old_stuff[:out],
			hostname: content["hostname"] || old_stuff[:hostname],
			level: (content["level"] || old_stuff[:level]).to_sym,
			prefix: (old_stuff[:prefix] || "") + (prefix || ""),
		}

		raise "No hostname" \
			unless new_stuff[:hostname]

		raise "No level" \
			unless new_stuff[:level]

		return new_stuff

	end

	def output_html content, stuff, prefix = ""

		stuff = fix_stuff stuff, content, prefix

		if content.is_a? String

			stuff[:out].print \
				stuff[:prefix],
				"<div class=\"hq-log-simple\">",
				esc_ht(content),
				"</div>\n"

			return

		end

		case content["type"]

		when "log"

			stuff[:out].print \
				stuff[:prefix],
				"<div class=\"hq-log-item hq-log-item-",
				esc_ht(content["level"].to_s),
				"\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t<div class=\"hq-log-head\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-hostname\">",
				esc_ht(stuff[:hostname]),
				"</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-text\">",
				esc_ht(content["text"]),
				"</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t</div>\n"

			if content["content"] && ! content["content"].empty?

				stuff[:out].print \
					stuff[:prefix],
					"\t<div class=\"hq-log-content\">\n"

				content["content"].each do
					|item|
					output_html item, stuff, "\t\t"
				end

				stuff[:out].print \
					stuff[:prefix],
					"\t</div>\n"

			end

			stuff[:out].print \
				stuff[:prefix],
				"</div>\n"

		when "exception"

			stuff[:out].print \
				stuff[:prefix],
				"<div class=\"hq-log-item hq-log-item-",
				esc_ht(content["level"]),
				"\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t<div class=\"hq-log-head\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-hostname\">",
				esc_ht(stuff[:hostname]),
				"</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-text\">",
				esc_ht(content["text"]),
				"</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t<div class=\"hq-log-content\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-exception\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t\t<div class=\"hq-log-exception-message\">",
				esc_ht(content["message"]),
				"</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t\t<div class=\"hq-log-exception-backtrace\">\n"

			content["backtrace"].each do
				|line|

				stuff[:out].print \
					stuff[:prefix],
					"\t\t\t\t<div class=\"hq-log-exception-backtrace-line\">",
					esc_ht(line),
					"</div>\n"

			end

			stuff[:out].print \
				stuff[:prefix],
				"\t\t\t</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"</div>\n"

		when "diff"

			stuff[:out].print \
				stuff[:prefix],
				"<div class=\"hq-log-item hq-log-item-",
				esc_ht(content["level"]),
				"\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t<div class=\"hq-log-head\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-hostname\">",
				esc_ht(stuff[:hostname]),
				"</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-text\">",
				esc_ht(content["text"]),
				"</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t<div class=\"hq-log-content\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-diff\">\n"

			content["content"].each do
				|line|

				stuff[:out].print \
					stuff[:prefix],
					"\t\t\t<div class=\"hq-log-",
					esc_ht(line["type"]),
					"\">",
					esc_ht(line["text"]),
					"</div>\n"

			end

			stuff[:out].print \
				stuff[:prefix],
				"\t\t</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"</div>\n"

		when "command"

			stuff[:out].print \
				stuff[:prefix],
				"<div class=\"hq-log-item hq-log-item-",
				esc_ht(content["level"]),
				"\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t<div class=\"hq-log-head\">\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-hostname\">",
				esc_ht(stuff[:hostname]),
				"</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-text\">",
				esc_ht(content["text"]),
				"</div>\n"

			stuff[:out].print \
				stuff[:prefix],
				"\t</div>\n"

			if content["output"]

				stuff[:out].print \
					stuff[:prefix],
					"\t<div class=\"hq-log-content\">\n"

				stuff[:out].print \
					stuff[:prefix],
					"\t\t<div class=\"hq-log-command-output\">\n"

				content["output"].each do
					|line|

					stuff[:out].print \
						stuff[:prefix],
						"\t\t\t<div class=\"hq-log-command-output-line\">",
						esc_ht(line),
						"</div>\n"

				end

				stuff[:out].print \
					stuff[:prefix],
					"\t\t</div>\n"

				stuff[:out].print \
					stuff[:prefix],
					"\t</div>\n"

			end

			stuff[:out].print \
				stuff[:prefix],
				"</div>\n"

		else

			pp content

		end

	end

	def ansi_line text, stuff, colour, prefix = ""

		raise "No such colour: #{colour}" \
			unless MESSAGE_COLOURS[colour] || ANSI_CODES[colour]

		stuff[:out].print \
			ANSI_CODES[:bold],
			ANSI_CODES[MESSAGE_COLOURS[:hostname]],
			stuff[:hostname],
			": ",
			ANSI_CODES[colour] || ANSI_CODES[MESSAGE_COLOURS[colour]],
			stuff[:prefix] + prefix,
			text,
			ANSI_CODES[:normal],
			"\n"

	end

	def output_ansi content, stuff = {}, prefix = ""

		stuff = fix_stuff stuff, content, prefix

		if content.is_a? String
			ansi_line content, stuff, :normal
			return
		end

		case content["type"]

		when "log"

			ansi_line content["text"], stuff, stuff[:level]

			if content["content"]
				content["content"].each do
					|item|
					output_ansi item, stuff, "  "
				end
			end

		when "exception"

			ansi_line content["text"], stuff, stuff[:level]
			ansi_line content["message"], stuff, :normal, "  "

			content["backtrace"].each do |frame|
				ansi_line frame, stuff, :normal, "    "
			end

		when "diff"

			ansi_line content["text"], stuff, stuff[:level]

			content["content"].each do
				|line|
				colour = DIFF_COLOURS[line["type"].gsub("-", "_")[5..-1].to_sym]
				ansi_line line["text"], stuff, colour, "  "
			end

		when "command"

			ansi_line content["text"], stuff, stuff[:level]

			if content["output"]

				content["output"].each do
					|line|
					ansi_line line, stuff, :normal, "  "
				end

			end

		when "command-output"

			ansi_line content["text"], stuff, :normal, "  "

		else

			pp content
			raise "Error"

		end

	end

	def text_line text, stuff, prefix = ""

		stuff[:out].print \
			stuff[:hostname],
			" ",
			stuff[:level],
			": ",
			stuff[:prefix] + prefix,
			text,
			"\n"

	end

	def output_text content, stuff = {}, prefix = ""

		stuff = fix_stuff stuff, content, prefix

		if content.is_a? String
			text_line content, stuff
			return
		end

		case content["type"]

		when "log"

			text_line content["text"], stuff

			if content["content"]

				content["content"].each do
					|item|
					output_text item, stuff, "  "
				end

			end

		when "exception"

			text_line content["text"], stuff
			text_line content["message"], stuff, "  "

			content["backtrace"].each do
				|frame|
				output_text frame, stuff, "    "
			end

		when "diff"

			text_line content["text"], stuff

			content["content"].each do
				|line|
				output_text line["text"], stuff, "  "
			end

		when "command"

			text_line content["text"], stuff

			if content["output"]

				content["output"].each do
					|line|
					output_text line, stuff, "  "
				end

			end

		when "command-output"

			text_line content["text"], stuff, "  "

		else

			pp content
			raise "Error"

		end

	end

	def level_includes level_1, level_2

		index_1 =
			MESSAGE_TYPES.index(level_1.to_sym)

		index_2 =
			MESSAGE_TYPES.index(level_2.to_sym)

		return index_1 <= index_2

	end

	def output_raw content, stuff

		data = {
			mode: stuff[:mode],
			content: [ content ],
		}

		stuff[:out].print MultiJson.dump(data) + "\n"

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

			case target[:format]

			when :html
				next if mode == :partial
				output_html content, stuff

			when :ansi
				next if mode == :complete
				output_ansi content, stuff

			when :text
				next if mode == :complete
				output_text content, stuff

			when :raw
				output_raw content, stuff

			else
				raise "Invalid target format: #{target[:format]}"

			end

			target[:out].flush

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
