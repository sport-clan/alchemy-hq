module HQ
module Tools
module Random

	def self.lower_case length = 20
		chars = "abcdefghijklmnopqrstuvwxyz"
		return (0...length).map { chars[rand chars.length] }.join("")
	end

end
end
end
