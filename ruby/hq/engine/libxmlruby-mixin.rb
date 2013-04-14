module HQ
module Engine
module LibXmlRubyMixin

	def load_data_file filename

		ret = []

		doc =
			XML::Document.file \
				filename,
				:options =>XML::Parser::Options::NOBLANKS

		return doc.find("//data/*").to_a

	end

	def load_data_string string

		ret = []

		doc =
			XML::Document.string \
				string,
				:options =>XML::Parser::Options::NOBLANKS

		return doc.find("//data/*").to_a

	end

	def write_data_file filename, data

		doc = XML::Document.new
		doc.root = XML::Node.new "data"

		data.each do
			|item|
			doc.root << doc.import(item)
		end

		File.open filename, "w" do |f|
			f.print doc.to_s
		end

	end


	def load_schema_file filename

		schema_doc =
			XML::Document.file filename

		schema =
			Hash[
				schema_doc.find("*").map do
					|schema_elem|
					[
						"%s/%s" % [
							schema_elem.name,
							schema_elem["name"],
						],
						schema_elem,
					]
				end
			]

		return schema

	end

	def field_to_json schemas, schema_elem, fields_elem, elem, value

		fields_elem.find(
			"* [name() != 'option']
		").each do
			|field_elem|

			field_name =
				field_elem["name"]

			case field_elem.name

				when "text"

					value[field_name] =
						elem[field_name]

				when "int", "ts-update"

					temp = elem.attributes[field_name]

					value[field_name] = temp.empty? ? nil : temp.to_i

				when "list"

					value[field_name] = []

					elem.find("* [ name () = #{xp field_name} ]") \
						.each do |child_elem|

						prop = {}

						field_to_json \
							schemas,
							schema_elem,
							field_elem,
							child_elem,
							prop

						value[field_name] << prop
					end

				when "struct"

					prop = {}

					child_elem =
						elem.find_first \
							"* [ name () = #{xp field_name} ]"

					if child_elem
						field_to_json \
							schemas,
							schema_elem,
							field_elem,
							child_elem,
							prop
					end

					value[field_name] = prop unless prop.empty?

				when "xml"

					value[field_name] = ""

					elem.find("* [ name () = #{xp field_name} ] / *") \
						.each do |prop|

						value[field_name] += prop.to_s
					end

				when "bool"

					value[field_name] = \
						elem.attributes[field_name] == "yes"

				when "bigtext"

					value[field_name] =
						elem.find_first("* [ name () = #{xp field_name} ]") \
							.content

				else

					raise "unexpected element #{field_elem.name} found in " \
						"field list for schema " \
						"#{schema_elem.attributes["name"]}"

			end
		end

		content = []

		elem.find("*").each do |child_elem|

			option_elem =
				fields_elem.find_first \
					"option [ @name = #{xp child_elem.name} ]"

			next unless option_elem

			option_ref =
				option_elem.attributes["ref"]

			schema_option_elem =
				schemas["schema-opion/#{option_ref}"]

			raise "Error" \
				unless schema_option_elem

			schema_option_props_elem =
				schema_option_elem.find_first "props"

			prop = {}

			field_to_json \
				schemas,
				schema_elem,
				schema_option_props_elem,
				child_elem,
				prop

			content << {
				"type" => child_elem.name,
				"value" => prop,
			}

		end

		value["content"] = content \
			unless content.empty?

	end

	def js_to_xml schemas, type, value

		schema_elem =
			schemas["schema/#{type}"]

		elem =
			XML::Node.new type

		field_to_xml \
			schemas,
			schema_elem.find_first("id"),
			value,
			elem

		field_to_xml \
			schemas,
			schema_elem.find_first("fields"),
			value,
			elem

		return elem

	end

	def xml_to_json schemas, schema_elem, elem

		value = {}

		field_to_json \
			schemas,
			schema_elem,
			schema_elem.find_first("id"),
			elem,
			value

		field_to_json \
			schemas,
			schema_elem,
			schema_elem.find_first("fields"),
			elem,
			value

		return value
	end

	def field_to_xml schemas, fields_elem, value, elem

		unless value.is_a? Hash
			value = {}
		end

		fields_elem.find("
			* [name() != 'option']
		").each do
			|field_elem|

			field_name =
				field_elem["name"]

			case field_elem.name

			when "text", "int", "ts-update", "enum"
				elem[field_name] = value[field_name].to_s

			when "bigtext"
				prop = XML::Node.new field_name
				prop << value[field_name]
				elem << prop

			when "bool"
				elem[field_name] = "yes" if value[field_name]

			when "list"

				items = value[field_name]

				if items.is_a? Array

					items.each do
						|item|

						prop =
							XML::Node.new field_name

						field_to_xml \
							schemas,
							field_elem,
							item,
							prop

						elem << prop

					end

				end

			when "struct"

				prop =
					XML::Node.new field_name

				field_to_xml \
					schemas,
					field_elem,
					value[field_name],
					prop

				if prop.attributes.length + prop.children.size > 0
					elem << prop
				end

			when "xml"

				prop =
					XML::Node.new field_name

				temp_doc =
					XML::Document.string \
						"<xml>#{value[field_name]}</xml>",
						:options =>XML::Parser::Options::NOBLANKS

				temp_doc.root.each do
					|temp_elem|
					prop << temp_elem.copy(true)
				end

				elem << prop

			else

				raise "unexpected element #{field_elem.name} found in field "
					"list for schema #{schema_elem["name"]}"

			end

		end

		if value["content"].is_a? Array

			value["content"].each do
				|item|

				item_type = item["type"]
				item_value = item["value"]

				option_elem =
					fields_elem.find_first "
						option [@name = '#{item_type}']
					"

				next unless option_elem

				option_ref =
					option_elem["ref"]

				schema_option_elem =
					schemas["schema-option/#{option_ref}"]

				next unless schema_option_elem

				schema_option_props_elem =
					schema_option_elem.find_first "props"

				prop =
					XML::Node.new item_type

				field_to_xml \
					schemas,
					schema_option_props_elem,
					item_value,
					prop

				elem << prop

			end

		end

	end

	def get_record_id_short schemas, record_elem

		schema_elem =
			schemas["schema/#{record_elem.name}"]

		unless schema_elem
			raise "No schema for #{record_elem.name}"
		end

		id_parts =
			schema_elem.find("id/*").to_a.map do
				|id_elem|

				part =
					record_elem[id_elem["name"]]

				unless part
					raise "No #{id_elem["name"]} for #{record_elem.name}"
				end

				part

			end

		id =
			id_parts.join "/"

		return id

	end

	def get_record_id_long schemas, record_elem

		return "%s/%s" % [
			record_elem.name,
			get_record_id_short(schemas, record_elem),
		]

	end

	def to_xml_string elem
		return elem.to_s
	end

end
end
end
