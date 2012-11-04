module Mandar::Bind

	def self.output_props(parent_elem, f, indent = "")
		parent_elem.find("prop").each do |prop_elem|
			prop_name = prop_elem.attributes["name"]
			prop_value = prop_elem.attributes["value"]
			f.print "#{indent}#{prop_name} #{prop_value}" if prop_name && prop_value
			f.print "#{indent}#{prop_name}" if prop_name && ! prop_value
			f.print "#{indent}#{prop_value}" if ! prop_name && prop_value
			unless prop_elem.find("*").empty?
				f.print " {\n"
				output_props prop_elem, f, "#{indent}  "
				f.print "#{indent}}"
			end
			f.print ";\n";
		end
	end

	Mandar::Deploy::Formats.register self, :bind_conf
	Mandar::Deploy::Formats.register self, :bind_zone

	def self.format_bind_conf(file_elem, f)
		output_props file_elem, f
	end

	def self.format_bind_zone(file_elem, f)

		require "hq/tools/table"

		table = HQ::Tools::Table.new

		last_rec_name = nil
		file_elem.find("*").each do |elem|
			case elem.name

			when "directive"

				dir_name = elem.attributes["name"]
				dir_value = elem.attributes["value"]
				table.push [
					"$#{dir_name} #{dir_value}"
				], "directive"

			when "record"

				rec_name = elem.attributes["name"] || ""
				rec_ttl = elem.attributes["ttl"] || ""
				rec_class = elem.attributes["class"] || ""
				rec_type = elem.attributes["type"] || ""
				rec_value = elem.attributes["value"] || ""

				table.push [
					rec_name == last_rec_name ? "" : rec_name,
					rec_ttl,
					rec_class,
					rec_type,
					rec_value,
				], "record"

				last_rec_name = rec_name

			end
		end

		table.print f
	end

	def self.check_bind_zone(path)
		cmd = "named-checkzone zone #{path}"
		ret = Mandar::Support::Core.shell_real cmd, :log => false
		return true if ret[:status] == 0
		Mandar.message(([ cmd ] + ret[:output]).join("\n"), :detail)
		return false
	end

end
