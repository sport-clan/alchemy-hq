module Mandar::Nagios

	Mandar::Deploy::Formats.register self, :nagios_config
	Mandar::Deploy::Formats.register self, :nagios_objects

	def self.format_nagios_config(file_elem, f)

		f.print "#\n"
		f.print "# This file is generated. Please do not edit.\n"
		f.print "#\n"

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "prop"
				prop_name = elem0.attributes["name"]
				prop_value = elem0.attributes["value"]
				f.print "#{prop_name}=#{prop_value}\n"

			else
				raise "Unexpected #{elem0.name} element"
			end
		end
	end

	def self.format_nagios_objects(file_elem, f)

		f.print "#\n"
		f.print "# This file is generated. Please do not edit.\n"
		f.print "#\n"

		table = Mandar::Tools::Table.new

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "define"
				define_name = elem0.attributes["name"]
				f.print "define #{define_name} {\n"

				elem0.find("*").each do |elem1|
					case elem1.name

					when "prop"
						prop_name = elem1.attributes["name"]
						prop_value = elem1.attributes["value"].gsub(";", "\\;")
						f.print "\t#{prop_name} #{prop_value}\n"

					else
						raise "Unexpected #{elem0.name} element"

					end
				end

				f.print "}\n"

			else
				raise "Unexpected #{elem0.name} element"

			end
		end

		table.print f
	end

end
