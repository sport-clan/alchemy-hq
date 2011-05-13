module Mandar::Support::LogRotate

	Mandar::Deploy::Formats.register self, :logrotate_conf

	def self.format_logrotate_conf(file_elem, f)

		f.print "#\n"
		f.print "# This file is generated. Please do not edit.\n"
		f.print "#\n"

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "section"
				section_name = elem0.attributes["name"]
				f.print "#{section_name} {\n"

				elem0.find("*").each do |elem1|
					case elem1.name

					when "prop"
						prop_name = elem1.attributes["name"]
						prop_value = elem1.attributes["value"]
						f.print "\t#{prop_name} #{prop_value}\n"

					when "script"
						script_name = elem1.attributes["name"]
						f.print "\t#{script_name}\n"

						elem1.find("*").each do |elem2|
							case elem2.name

							when "line"
								line_value = elem2.attributes["value"]
								f.print "\t\t#{line_value}\n"

							else
								raise "Unexpected #{elem1.name} element"
							end
						end

						f.print "\tendscript\n"

					when "comment"
						comment_value = elem1.attributes["value"]
						f.print "\# #{comment_value}\n"

					else
						raise "Unexpected #{elem1.name} element"
					end
				end

				f.print "}\n"

			when "comment"
				comment_value = elem0.attributes["value"]
				f.print "\# #{comment_value}\n"

			else
				raise "Unexpected #{elem0.name} element"
			end
		end
	end

end
