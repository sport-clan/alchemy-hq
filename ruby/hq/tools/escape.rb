require "hq/tools"

require "cgi"

module HQ
module Tools
module Escape

	# various escape functions

	def self.html str
	   return CGI::escapeHTML str
	end

	def self.url str
	   return CGI::escape str
	end

	def self.xpath str
		return "'" + str.gsub("'", "''") + "'"
	end

	def self.shell str

		# recurse into arrays and join with space

		return str.map { |a| shell a }.join(" ") \
			if str.is_a?(Array)

		# simple strings require no encoding

		return str \
			if str =~ /^[-a-zA-Z0-9_\/:.=@]+$/

		# single quotes preferred

		unless str =~ /'/
			return \
				"'" +
				str.gsub("'", "'\\\\''") +
			"'"
		end

		# else double quotes

		return \
			"\"" +
			str.gsub("\\", "\\\\\\\\")
				.gsub("\"", "\\\\\"")
				.gsub("`", "\\\\`")
				.gsub("$", "\\\\$") +
			"\""

	end

	# also function as a handy mixin

	def esc_ht str
		return Escape.html str
	end

	def esc_ue str
		return Escape.url str
	end

	def esc_xp str
		return Escape.xpath str
	end

	def esc_shell str
		return Escape.shell str
	end

end
end
end
