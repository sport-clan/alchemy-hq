require "hq"

module HQ::CouchDB

	def self.urlf url, *args
		ret = ""
		url.each_char do |char|
			if char != "%"
				ret << char
				next
			end
			z = args.unshift
			ret << CGI::escape(args.shift)
		end
		return ret
	end

	def self.map_error response

		error = response["error"]
		reason = response["reason"]

		return case error

			when "not_found"
				CouchNotFoundException.new "CouchDB error: #{error}: #{reason}"

			else
				CouchException.new "CouchDB error: #{error}: #{reason}"

		end

	end

	class CouchException < Exception
	end

	class CouchNotFoundException < CouchException
	end

end
