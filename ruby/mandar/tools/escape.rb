module Mandar::Tools::Escape

	def xp str
		return "'" + str.gsub("'", "''") + "'"
	end

end
