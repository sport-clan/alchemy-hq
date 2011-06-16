module Mandar::Support::Apache

	Mandar::Deploy::Formats.register self, :apache_conf

	def self.output_elems(parent_elem, f, indent = "")
		parent_elem.find("*").each do |child_elem|
			child_name = child_elem.attributes["name"]
			child_value = child_elem.attributes["value"]
			case child_elem.name

			when "section"
				f.puts "#{indent}<#{child_name} #{child_value}>"
				output_elems child_elem, f, "#{indent}\t"
				f.puts "#{indent}</#{child_name}>"

			when "prop"
				f.puts "#{indent}#{child_name} #{child_value}"

			when "comment"
				f.puts "#{indent}; #{child_value}"

			when "literal"
				value = child_elem.find "string (value)"
				value.split(/[\r\n]+/).each do |line|
					f.puts "#{indent}#{line}"
				end

			else
				raise "Unexpected #{child_elem.name} element"

			end
		end
	end

	def self.format_apache_conf(file_elem, f)

		f.print "#\n# This file is generated. Please do not edit.\n#\n"

		output_elems file_elem, f
	end

end
