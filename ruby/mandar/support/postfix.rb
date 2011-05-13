module Mandar::Postfix

	Mandar::Deploy::Formats.register self, :postfix_main
	Mandar::Deploy::Formats.register self, :postfix_master
	Mandar::Deploy::Formats.register self, :postfix_aliases
	Mandar::Deploy::Formats.register self, :postfix_hash

	def self.format_postfix_main(file_elem, f)

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

	def self.format_postfix_master(file_elem, f)

		f.print "#\n"
		f.print "# This file is generated. Please do not edit.\n"
		f.print "#\n"

		table = Mandar::Tools::Table.new

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "service"
				table.push [
					elem0.attributes["name"] || "-",
					elem0.attributes["type"] || "-",
					elem0.attributes["private"] || "-",
					elem0.attributes["unpriv"] || "-",
					elem0.attributes["chroot"] || "-",
					elem0.attributes["wakeup"] || "-",
					elem0.attributes["maxproc"] || "-",
					elem0.attributes["cmd"] || "-",
				]

			else
				raise "Unexpected #{elem0.name} element"

			end
		end

		table.print f
	end

	def self.format_postfix_hash(file_elem, f)

		f.print "#\n"
		f.print "# This file is generated. Please do not edit.\n"
		f.print "#\n"

		table = Mandar::Tools::Table.new

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "entry"
				table.push [
					"#{elem0.attributes["key"]}",
					"#{elem0.attributes["value"]}",
				]

			else
				raise "Unexpected #{elem0.name} element"

			end
		end

		table.print f
	end

	def self.format_postfix_aliases(file_elem, f)

		f.print "#\n"
		f.print "# This file is generated. Please do not edit.\n"
		f.print "#\n"

		table = Mandar::Tools::Table.new

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "alias"
				table.push [
					"#{elem0.attributes["source"]}:",
					"#{elem0.attributes["dest"]}",
				]

			else
				raise "Unexpected #{elem0.name} element"

			end
		end

		table.print f
	end

end
