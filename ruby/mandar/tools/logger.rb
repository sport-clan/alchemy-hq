class Mandar::Tools::Logger

	attr_accessor :target
	attr_accessor :format
	attr_accessor :level

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
		:hostname => :blue,
		:trace => :magenta,
		:debug => :cyan,
		:detail => :white,
		:notice => :green,
		:warning => :yellow,
		:error => :red,
	}

	def initialize
		@target = STDOUT
		@format = :ansi
	end

	def would_log(type)
		return MESSAGE_TYPES.index(type) >= MESSAGE_TYPES.index(level)
	end

	def message(text, type, options = {})

		if text.is_a? Array
			text.each do |item|
				message item, type
			end
			return
		end

		return unless would_log(type)

		if @format == :html

			text_html = options[:html] ? text \
				: "<div class=\"mandar-log-plain\">#{CGI::escapeHTML text}</div>"
			@target.print [
				"<div class=\"mandar-log-item mandar-log-item-#{type}\">\n",
				"\t<div class=\"mandar-log-hostname\">#{Mandar.host}:</div>\n",
				"\t<div class=\"mandar-log-content\">#{text_html}</div>\n",
				"</div>\n",
			].join ""

		else

			if text =~ /\n/
				text.split(/\n/).each do |line|
					message line, type
				end
				return
			end

			colour = options[:colour] || MESSAGE_COLOURS[type]

			@target.print [
				ANSI_CODES[:bold],
				ANSI_CODES[MESSAGE_COLOURS[:hostname]],
				"#{Mandar.host}: ",
				ANSI_CODES[colour],
				"#{text}",
				ANSI_CODES[:normal],
				"\n",
			].join ""

		end
	end

end
