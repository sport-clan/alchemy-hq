require "hq/tools/logger/formatter"

class HQ::Tools::Logger::TextFormatter \
	< HQ::Tools::Logger::Formatter

	def valid_modes
		[ :normal, :partial ]
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

	def output content, stuff = {}, prefix = ""

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
					output item, stuff, "  "
				end

			end

		when "exception"

			text_line content["text"], stuff
			text_line content["message"], stuff, "  "

			content["backtrace"].each do
				|frame|
				output frame, stuff, "    "
			end

		when "diff"

			text_line content["text"], stuff

			content["content"].each do
				|line|
				output line["text"], stuff, "  "
			end

		when "command"

			text_line content["text"], stuff

			if content["output"]

				content["output"].each do
					|line|
					output line, stuff, "  "
				end

			end

		when "command-output"

			text_line content["text"], stuff, "  "

		else

			pp content
			raise "Error"

		end

	end

end
