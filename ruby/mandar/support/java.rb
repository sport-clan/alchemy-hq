module Mandar::Support::Java

	Mandar::Deploy::Formats.register self, :java_properties

	def self.format_java_properties(file_elem, f)

		f.print "#\n"
		f.print "# This file is generated. Please do not edit.\n"
		f.print "#\n"

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "prop"
				prop_name = elem0.attributes["name"]
				prop_value = elem0.attributes["value"]
				f.print "#{prop_name} = #{prop_value}\n"

			else
				raise "Unexpected #{elem0.name} element"
			end
		end
	end

end
