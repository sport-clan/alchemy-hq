require "hq/tools/logger/io-logger"

class HQ::Tools::Logger::AnsiLogger \
	< HQ::Tools::Logger::IoLogger

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

	DIFF_COLOURS = {
		:minus_minus_minus => :magenta,
		:plus_plus_plus => :magenta,
		:at_at => :magenta,
		:minus => :red,
		:plus => :blue,
		:else => :white,
	}

	def valid_modes
		[ :normal, :partial ]
	end

	def ansi_line text, stuff, colour, prefix = ""

		raise "No such colour: #{colour}" \
			unless MESSAGE_COLOURS[colour] || ANSI_CODES[colour]

		out.print \
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

	def output_real content, stuff

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
					output item, stuff, "  "
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

end
