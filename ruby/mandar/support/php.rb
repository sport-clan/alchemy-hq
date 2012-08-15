module Mandar::Support::PHP

	Mandar::Deploy::Formats.register self, :php
	Mandar::Deploy::Formats.register self, :php_ini

	def self.check_constant(name)
		return if name =~ /^[a-zA-Z_\x7f-\xff][a-zA-Z0-9_\x7f-\xff]*$/
		raise "Invalid constant name: #{name}"
	end

	def self.check_variable(name)
		return if name =~ /^[a-zA-Z_\x7f-\xff][a-zA-Z0-9_\x7f-\xff]*$/
		raise "Invalid variable name: #{name}"
	end

	def self.format_php(file_elem, f)

		f.print "<?php\n"
		f.print "//\n"
		f.print "// This file is generated. Please do not edit.\n"
		f.print "//\n"

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "define"
				check_constant define_name = elem0.attributes["name"]
				define_value = elem0.attributes["value"]
				if define_value
					f.print "define (#{to_php define_name}, #{to_php define_value});\n"
				else
					config = Mandar::Support::ConfigFuncs.xml_to_config elem0.find_first("*")
					f.puts "define (#{to_php define_name}, #{to_php config});\n"
				end

			when "string-var"
				check_variable var_name = elem0.attributes["name"]
				var_value = elem0.attributes["value"]
				f.print "$#{var_name} = #{to_php var_value};\n"

			when "bool-var"
				check_variable var_name = elem0.attributes["name"]
				var_value = elem0.attributes["value"]
				f.print "$#{var_name} = #{to_php var_value == "yes"};\n"

			when "const-var"
				check_variable var_name = elem0.attributes["name"]
				check_constant var_value = elem0.attributes["value"]
				f.print "$#{var_name} = #{var_value};\n"

			when "variable"
				check_variable var_name = elem0.attributes["name"]
				config = Mandar::Support::ConfigFuncs.xml_to_config elem0.find_first("*")
				f.puts "$#{var_name} = #{to_php config};\n"

			when "ini-set"

				ini_set_name = elem0.attributes["name"].to_s
				ini_set_value = elem0.attributes["value"]
				ini_set_type = elem0.attributes["type"]

				value = case ini_set_type

					when "string", nil
						ini_set_value.to_s

					when "int"
						ini_set_value.to_i

					else
						raise "Error"
				end

				f.puts "ini_set (#{to_php ini_set_name}, #{to_php value});"

			else
				raise "Unexpected #{elem0.name} element"

			end
		end
	end

	def self.format_php_ini(file_elem, f)

		file_elem.find("*").each do |elem0|
			case elem0.name

			when "section"
				section_name = elem0.attributes["name"]
				f.print "[#{section_name}]\n"

				elem0.find("*").each do |elem1|
					case elem1.name

					when "prop"
						prop_name = elem1.attributes["name"]
						prop_value = elem1.attributes["value"]
						f.print "#{prop_name} = #{prop_value}\n"

					when "comment"
						comment_value = elem1.attributes["value"]
						f.print ";#{comment_value}\n"

					else
						raise "Unexpected #{elem1.name} element"
					end
				end

			when "prop"
				prop_name = elem0.attributes["name"]
				prop_value = elem0.attributes["value"]
				f.print "#{prop_name} = #{prop_value}\n"

			when "comment"
				comment_value = elem0.attributes["value"]
				f.print ";#{comment_value}\n"

			else
				raise "Unexpected #{elem0.name} element"

			end
		end
	end

	def self.to_php(value, indent = "", tab = "  ")
		indent2 = indent + tab
		case value

		when String
			escaped = ""
			value.each_char do |ch|
				escaped += case ch
					when "\n"; "\\r"
					when "\r"; "\\r"
					when "\t"; "\\t"
					when "\v"; "\\v"
					when "\f"; "\\f"
					when "\\"; "\\\\"
					when "$"; "\\$"
					when "\""; "\\\""
					else ch
				end
			end
			return "\"#{escaped}\""

		when Fixnum then
			return value.to_s

		when FalseClass then
			return "false"

		when TrueClass then
			return "true"

		when Hash then
			return "array (\n" + value.to_a.map { |k,v|
				"#{indent2}#{to_php k, indent2, tab} => #{to_php v, indent2, tab}" }.join(",\n") + ")"

		when Array then
			return "array (\n" + value.map { |v| "#{indent2}#{to_php v, indent2, tab}" }.join(",\n") + ")"

		else
			raise "Can't convert #{value.class} to php"
		end
	end

	Mandar::Deploy::Commands.register self, :pecl_install
	Mandar::Deploy::Commands.register self, :pecl_purge

	def self.command_pecl_install pecl_install_elem

		pecl_install_package = pecl_install_elem.attributes["package"]
		pecl_install_version = pecl_install_elem.attributes["version"]

		@pecl_installed ||= {}

		raise "Multiple versions for pecl package #{pecl_install_package}" \
			if @pecl_installed[pecl_install_package]

		@pecl_installed[pecl_install_package] = pecl_install_version

		return if pecl_packages[pecl_install_package] == pecl_install_version

		Mandar.notice "installing pecl package #{pecl_install_package} " +
			"#{pecl_install_version}"

		Mandar::Deploy::Flag.auto

		unless $mock

			install_args = [
				"pecl",
				"install",
				"--force",
				"#{pecl_install_package}-#{pecl_install_version}",
			]

			install_cmd =
				Mandar.shell_quote install_args

			system install_cmd \
				or raise "Error"

		end

	end

	def self.command_pecl_purge pecl_purge_elem

		@pecl_installed ||= {}

		to_remove = pecl_packages.keys - @pecl_installed.keys

		return if to_remove.empty?

		Mandar::Deploy::Flag.auto

		to_remove.each do |package|

			Mandar.notice "removing pecl package #{package}"

			next if $mock

			remove_args = [
				"pecl",
				"uninstall",
				"#{package}",
			]

			remove_cmd =
				Mandar.shell_quote remove_args

			system remove_cmd \
				or raise "Error"

		end

	end

	NAME_RE = /[a-z][a-z0-9]*(?:-[a-z][a-z0-9]*)*/
	VER_RE = /[0-9]+(?:\.[0-9]+)*/

	def self.pecl_packages force = false

		# use saved value after first run

		return @pecl_packages if @pecl_packages && ! force

		# install required package php-pear

		Mandar::Debian.apt_install "php-pear"

		# run "pecl list" and iterate output

		pecl_packages = {}

		%x[ pecl list ].split("\n").each do |line|

			case line

			when /^INSTALLED PACKAGES, CHANNEL .+:$/,
					/^[=]+$/,
					/^PACKAGE VERSION STATE$/,
					/^\(no packages installed from channel .+\)$/

				# skip

			when /^(#{NAME_RE})\s+(#{VER_RE})\s+(#{NAME_RE})$/

				# save

				pecl_packages[$1] = $2

			else

				# error

				raise "Invalid output from 'pecl list': \"#{line}\""

			end
		end

		# return

		return @pecl_packages = pecl_packages

	end

end
