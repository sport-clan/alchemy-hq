module Mandar::Support::JSON

	Mandar::Deploy::Formats.register self, :json
	Mandar::Deploy::Formats.register self, :json_lines

	def self.format_json file_elem, f

		file_elem.find("*").each do |elem|

			config =
				Mandar::Support::ConfigFuncs.xml_to_config elem

			json =
				MultiJson.dump \
					config,
					:pretty => true

			f.puts json

		end

	end

	def self.format_json_lines file_elem, f

		file_elem.find("*").each do |elem|

			config =
				Mandar::Support::ConfigFuncs.xml_to_config elem

			json =
				MultiJson.dump config

			f.puts json

		end

	end

end
