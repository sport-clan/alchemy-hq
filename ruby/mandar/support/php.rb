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
				f.print "define (#{to_php define_name}, #{to_php define_value});\n"

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

			else
				raise "Unexpected #{elem0.name} element"

			end
		end
	end

	def self.format_php_ini(file_elem, f)

		file_elem.find("*").each do |elem|
			case elem.name

			when "section"
				section_name = elem.attributes["name"]
				f.print "[#{section_name}]\n"

			when "prop"
				prop_name = elem.attributes["name"]
				prop_value = elem.attributes["value"]
				f.print "#{prop_name} = #{prop_value}\n"

			when "comment"
				comment_value = elem.attributes["value"]
				f.print ";#{comment_value}\n"

			else
				raise "Unexpected #{elem.name} element"

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

	Mandar::Deploy::Commands.register self, :pecl

	def self.command_pecl(pecl_elem)

		pecl_package = pecl_elem.attributes["package"]
		pecl_version = pecl_elem.attributes["version"]

		return if pecl_packages[pecl_package] == pecl_version

		puts "installing #{pecl_package} #{pecl_version} from pecl"
		Mandar::Deploy::Flag.auto
		system "pecl install --force #{pecl_package}-#{pecl_version}" or raise "Error" unless $mock
	end

	NAME_RE = /[a-z][a-z0-9]*(?:-[a-z][a-z0-9]*)*/
	VER_RE = /[0-9]+(?:\.[0-9]+)*/

	def self.pecl_packages(force = false)

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
