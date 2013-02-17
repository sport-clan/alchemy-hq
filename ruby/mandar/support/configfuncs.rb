module Mandar::Support::ConfigFuncs

	def self.xml_to_config elem0
		case elem0.name

		when "boolean"
			return elem0.attributes["value"] == "yes"

		when "string"
			return elem0.attributes["value"]

		when "integer"
			return elem0.attributes["value"].to_i

		when "map"
			ret = {}
			elem0.find("*").each do |elem1|
				ret[elem1.attributes["name"]] = xml_to_config elem1
			end
			return ret

		when "array"
			ret = []
			elem0.find("*").each do |elem1|
				ret << xml_to_config(elem1)
			end
			return ret

		when "json"
			return MultiJson.load elem0.find("string (json)")

		else
			raise "Don't know how to convert #{elem0.name}"
		end
	end

end
