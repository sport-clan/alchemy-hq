module Mandar::Support::MySQL

	Mandar::Deploy::Formats.register self, :mysql_cnf

	def self.format_mysql_cnf(file_elem, f)

		f.print "#\n"
		f.print "# This file is generated. Please do not edit.\n"
		f.print "#\n"

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "section"
				section_name = elem0.attributes["name"]
				f.print "[#{section_name}]\n"

				elem0.find("*").each do |elem1|
					case

					when "prop"
						prop_name = elem1.attributes["name"]
						prop_value = elem1.attributes["value"]
						if prop_value
							f.print "#{prop_name} = #{prop_value}\n"
						else
							f.print "#{prop_name}\n"
						end

					else
						raise "Unexpected #{elem1.name} element"
					end
				end

			else
				raise "Unexpected #{elem0.name} element"
			end
		end
	end

end
