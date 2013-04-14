module HQ
module XQuery
class XQueryError < RuntimeError

	attr_accessor :file
	attr_accessor :line
	attr_accessor :column
	attr_accessor :message

	def to_s
		return "bananas"
	end

end
end
end
