module Mandar::Support::JSON

	Mandar::Deploy::Formats.register self, :json

	def self.format_json file_elem, f
		file_elem.find("*").each do |elem|
			config = Mandar::Support::ConfigFuncs.xml_to_config elem
			json = JSON.fast_generate config, :indent => "\t", :space => " ", :object_nl => "\n", :array_nl => "\n"
			f.puts json
		end
	end

end
