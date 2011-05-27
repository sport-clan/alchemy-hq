module Mandar::Tools::Escape

	def xp str
		return "'" + str.gsub("'", "''") + "'"
	end

	def ue str
	   return CGI::escape str
	end

end
