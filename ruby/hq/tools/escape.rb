require "hq/tools"

require "cgi"

module HQ::Tools::Escape

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

	# also function as a handy mixin

	def esc_ht str
		return HQ::Tools::Escape.html str
	end

	def esc_ue str
		return HQ::Tools::Escape.url str
	end

	def esc_xp str
		return HQ::Tools::Escape.xpath str
	end

end
