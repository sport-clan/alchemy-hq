require "hq/tools/escape"
require "hq/tools/logger/io-logger"

module HQ
module Tools
class Logger
class HtmlLogger < IoLogger

	include Tools::Escape

	def valid_modes
		[ :normal, :complete ]
	end

	def output_real content, stuff

		if content.is_a? String

			out.print \
				stuff[:prefix],
				"<div class=\"hq-log-simple\">",
				esc_ht(content),
				"</div>\n"

			return

		end

		case content["type"]

		when "log"

			out.print \
				stuff[:prefix],
				"<div class=\"hq-log-item hq-log-item-",
				esc_ht(content["level"].to_s),
				"\">\n"

			out.print \
				stuff[:prefix],
				"\t<div class=\"hq-log-head\">\n"

			out.print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-hostname\">",
				esc_ht(stuff[:hostname]),
				"</div>\n"

			out.print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-text\">",
				esc_ht(content["text"]),
				"</div>\n"

			out.print \
				stuff[:prefix],
				"\t</div>\n"

			if content["content"] && ! content["content"].empty?

				out.print \
					stuff[:prefix],
					"\t<div class=\"hq-log-content\">\n"

				content["content"].each do
					|item|
					output item, stuff, "\t\t"
				end

				out.print \
					stuff[:prefix],
					"\t</div>\n"

			end

			out.print \
				stuff[:prefix],
				"</div>\n"

		when "exception"

			out.print \
				stuff[:prefix],
				"<div class=\"hq-log-item hq-log-item-",
				esc_ht(content["level"]),
				"\">\n"

			out.print \
				stuff[:prefix],
				"\t<div class=\"hq-log-head\">\n"

			out.print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-hostname\">",
				esc_ht(stuff[:hostname]),
				"</div>\n"

			out.print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-text\">",
				esc_ht(content["text"]),
				"</div>\n"

			out.print \
				stuff[:prefix],
				"\t</div>\n"

			out.print \
				stuff[:prefix],
				"\t<div class=\"hq-log-content\">\n"

			out.print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-exception\">\n"

			out.print \
				stuff[:prefix],
				"\t\t\t<div class=\"hq-log-exception-message\">",
				esc_ht(content["message"]),
				"</div>\n"

			out.print \
				stuff[:prefix],
				"\t\t\t<div class=\"hq-log-exception-backtrace\">\n"

			content["backtrace"].each do
				|line|

				out.print \
					stuff[:prefix],
					"\t\t\t\t<div class=\"hq-log-exception-backtrace-line\">",
					esc_ht(line),
					"</div>\n"

			end

			out.print \
				stuff[:prefix],
				"\t\t\t</div>\n"

			out.print \
				stuff[:prefix],
				"\t\t</div>\n"

			out.print \
				stuff[:prefix],
				"\t</div>\n"

			out.print \
				stuff[:prefix],
				"</div>\n"

		when "diff"

			out.print \
				stuff[:prefix],
				"<div class=\"hq-log-item hq-log-item-",
				esc_ht(content["level"]),
				"\">\n"

			out.print \
				stuff[:prefix],
				"\t<div class=\"hq-log-head\">\n"

			out.print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-hostname\">",
				esc_ht(stuff[:hostname]),
				"</div>\n"

			out.print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-text\">",
				esc_ht(content["text"]),
				"</div>\n"

			out.print \
				stuff[:prefix],
				"\t</div>\n"

			out.print \
				stuff[:prefix],
				"\t<div class=\"hq-log-content\">\n"

			out.print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-diff\">\n"

			content["content"].each do
				|line|

				out.print \
					stuff[:prefix],
					"\t\t\t<div class=\"hq-log-",
					esc_ht(line["type"]),
					"\">",
					esc_ht(line["text"]),
					"</div>\n"

			end

			out.print \
				stuff[:prefix],
				"\t\t</div>\n"

			out.print \
				stuff[:prefix],
				"\t</div>\n"

			out.print \
				stuff[:prefix],
				"</div>\n"

		when "command"

			out.print \
				stuff[:prefix],
				"<div class=\"hq-log-item hq-log-item-",
				esc_ht(content["level"]),
				"\">\n"

			out.print \
				stuff[:prefix],
				"\t<div class=\"hq-log-head\">\n"

			out.print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-hostname\">",
				esc_ht(stuff[:hostname]),
				"</div>\n"

			out.print \
				stuff[:prefix],
				"\t\t<div class=\"hq-log-text\">",
				esc_ht(content["text"]),
				"</div>\n"

			out.print \
				stuff[:prefix],
				"\t</div>\n"

			if content["output"]

				out.print \
					stuff[:prefix],
					"\t<div class=\"hq-log-content\">\n"

				out.print \
					stuff[:prefix],
					"\t\t<div class=\"hq-log-command-output\">\n"

				content["output"].each do
					|line|

					out.print \
						stuff[:prefix],
						"\t\t\t<div class=\"hq-log-command-output-line\">",
						esc_ht(line),
						"</div>\n"

				end

				out.print \
					stuff[:prefix],
					"\t\t</div>\n"

				out.print \
					stuff[:prefix],
					"\t</div>\n"

			end

			out.print \
				stuff[:prefix],
				"</div>\n"

		else

			pp content

		end

	end

end
end
end
end
