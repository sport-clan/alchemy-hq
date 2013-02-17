require "hq/tools/escape"
require "hq/tools/logger/formatter"

class HQ::Tools::Logger::HtmlFormatter \
	< HQ::Tools::Logger::Formatter

	include HQ::Tools::Escape

	def valid_modes
		[ :normal, :complete ]
	end

	def output content, stuff, prefix = ""

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
					output item, stuff, "\t\t"
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

end
