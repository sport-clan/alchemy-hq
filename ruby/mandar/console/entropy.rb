class Mandar::Console::Entropy

	def rand_token length = 20
		chars = "abcdefghijklmnopqrstuvwxyz"
		return (0...length).map { chars[rand chars.length] }.join("")
	end

end
