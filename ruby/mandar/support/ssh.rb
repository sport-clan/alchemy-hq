module Mandar::Support::SSH

	Mandar::Deploy::Formats.register self, :ssh_config

	def self.format_ssh_config(file_elem, f)

		f.print "#\n"
		f.print "# This file is generated. Please do not edit.\n"
		f.print "#\n"

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "section"
				section_name = elem0.attributes["name"]
				section_value = elem0.attributes["value"]
				f.print "#{section_name}"
				f.print " #{section_value}" if section_value
				f.print "\n"

				elem0.find("*").each do |elem1|
					case elem1.name

					when "prop"
						prop_name = elem1.attributes["name"]
						prop_value = elem1.attributes["value"]
						f.print "\t#{prop_name} #{prop_value}\n"

					when "comment"
						comment_value = elem1.attributes["value"]
						f.print "\# #{comment_value}\n"

					else
						raise "Unexpected #{elem1.name} element"
					end
				end

			when "prop"
				prop_name = elem0.attributes["name"]
				prop_value = elem0.attributes["value"]
				f.print "#{prop_name} #{prop_value}\n"

			when "comment"
				comment_value = elem0.attributes["value"]
				f.print "\# #{comment_value}\n"

			else
				raise "Unexpected #{elem0.name} element"
			end
		end
	end

end
