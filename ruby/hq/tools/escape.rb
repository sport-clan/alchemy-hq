require "hq/tools"

module HQ::Tools::Escape

	# various escape functions

	def self.xpath str
		return "'" + str.gsub("'", "''") + "'"
	end

	def self.url str
	   return CGI::escape str
	end

	# also function as a handy mixin

	def esc_xp str
		return HQ::Tools::Escape.xpath str
	end

	def esc_ue str
		return HQ::Tools::Escape.url str
	end

end
