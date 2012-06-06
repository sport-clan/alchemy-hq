module Mandar::Tools::Escape

	# various escape functions

	def self.xpath str
		return "'" + str.gsub("'", "''") + "'"
	end

	def self.url str
	   return CGI::escape str
	end

	# also function as a handy mixin

	def xp str
		return Mandar::Tools::Escape.xpath str
	end

	def ue str
		return Mandar::Tools::Escape.url str
	end

end
