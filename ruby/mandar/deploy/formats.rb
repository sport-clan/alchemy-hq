module Mandar::Deploy::Formats

	def self.register(target, *format_syms)
		@formats ||= {}
		format_syms.each do |format_sym|
			format_name = format_sym.to_s.gsub("_", "-")
			@formats[format_name] and raise "Duplicate format #{format_name}"
			@formats[format_name] = { :target => target }
		end
	end

	def self.invoke(format_name, file_elem, file_handle)
		@formats ||= {}
		format = @formats[format_name]
		format or Mandar.die "No such format format_name"
		target = format[:target]
		function_name = "format_#{format_name.gsub("-", "_")}"
		target.send function_name, file_elem, file_handle
	end

	def self.check(format_name, path)
		@formats ||= {}
		format = @formats[format_name]
		format or Mandar.die "No such format format_name"
		target = format[:target]
		function_name = "check_#{format_name.gsub("-", "_")}"
		return true unless target.respond_to? function_name
		target.send function_name, path
	end

	def self.exists?(format_name)
		@formats ||= {}
		return @formats.has_key? format_name
	end

	register self, :table
	register self, :text
	register self, :xml

	def self.format_table(table_elem, f)

		require "hq/tools/table"

		table = HQ::Tools::Table.new

		table_elem.find("*").each do |elem0|
			case elem0.name

			when "warn"
				warn_prefix = elem0.attributes["prefix"]
				f.print "#{warn_prefix}\n"
				f.print "#{warn_prefix} This file is generated. Please do not edit.\n"
				f.print "#{warn_prefix}\n"

			when "row"
				row_cat = elem0.attributes["cat"] || "default"
				row_cols = []
				elem0.find("*").each do |elem1|
					case elem1.name

					when "col"
						row_cols << elem1.attributes["value"]

					else
						raise "Unexpected <#{elem1.name}> element"
					end
				end

				table.push row_cols, row_cat

			else
				raise "Unexpected <#{elem0.name}> element"
			end
		end

		table.print f
	end

	def self.format_text(text_elem, f)

		text_elem.find("*").each do |elem|
			case elem.name

			when "line"
				line_value = elem.attributes["value"]
				f.print "#{line_value}\n"

			when "warn"
				warn_prefix = elem.attributes["prefix"]
				f.print "#{warn_prefix}\n"
				f.print "#{warn_prefix} This file is generated. Please do not edit.\n"
				f.print "#{warn_prefix}\n"

			else
				raise "Unexpected <#{elem.name}> element"
			end
		end
	end

	def self.format_xml(file_elem, f)

		doc = XML::Document.new
		doc.root = doc.import file_elem.find_first("*")

		# kill whitespace
		doc.find("//text()").each do |e|
			e.remove! if e.content =~ /\A\s*\Z$/
		end

		# output
		f.print doc.to_s
	end

end
