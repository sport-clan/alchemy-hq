require "hq/engine"

module HQ
module Engine
class Engine

	attr_accessor :main

	def config_dir() main.config_dir end
	def couch() main.couch end
	def logger() main.logger end
	def work_dir() main.work_dir end

	def results
		transformer.results
	end

	def abstract

		return @abstract if @abstract

		abstract = {}

		transformer.results.each do
			|result_name, result|

			abstract[result_name] =
				result[:doc].root
		end

		return @abstract = abstract

	end

	def xquery_client

		return @xquery_client if @xquery_client

		require "hq/xquery/client"

		logger.debug "starting xquery server"

		spec =
			Gem::Specification.find_by_name "alchemy-hq"

		xquery_server =
			"#{spec.gem_dir}/c++/xquery-server"

		@xquery_client =
			HQ::XQuery.start xquery_server

	end

	def transformer

		return @transformer if @transformer

		require "hq/engine/transformer"

		@transformer =
			HQ::Engine::Transformer.new

		@transformer.logger = logger
		@transformer.xquery_client = xquery_client

		@transformer.config_dir = config_dir
		@transformer.work_dir = work_dir

		return @transformer

	end

	def transform

		return if warn_no_config

		# ensure work dir exists

		if File.exist? "#{work_dir}/error-flag"
			logger.warning "removing work directory due to previous error"
			FileUtils.rm_rf work_dir
		end

		FileUtils.mkdir_p work_dir

		# ensure schema doc exists and remember it

		schema_file = "#{work_dir}/schema.xml"

		unless File.exists? schema_file

			logger.trace "writing schema.xml (empty)"

			File.open schema_file, "w" do |f|
				f.print "<schemas/>"
			end

		end

		old_schema_data = File.read(schema_file)

		while true

			data_ready

			# process abstract config

			transformer.rebuild @data_docs

			# write new schema file

			logger.trace "writing schema.xml"
			Tempfile.open("alchemy-hq-schemas-xml-") do |f|
				doc = XML::Document.new
				doc.root = XML::Node.new "schemas"

				%W[ schema schema-option abstract-rule ].each do |elem_name|
					schema_result = transformer.results[elem_name]
					if schema_result
						schema_result[:doc].root.find(elem_name).each do |schema_elem|
							doc.root << doc.import(schema_elem)
						end
					end
				end
				doc_str = doc.to_s
				f.puts doc_str
				f.flush
				FileUtils.move f.path, schema_file
			end
			@schemas_elem = nil

			# if schema file hasn't changed then we're done, otherwise start again

			new_schema_data = File.read(schema_file)
			break if new_schema_data == old_schema_data
			old_schema_data = new_schema_data
			logger.notice "restart due to schema changes"

		end

	end

	def warn_no_config
		return false unless $no_config
		return true if @warned_no_config
		logger.warning "not rebuilding configuration due to --no-config option"
		@warned_no_config = true
		return true
	end

	def data_ready
		if $no_database
			logger.warning "not dumping data due to --no-database option"
			data_load
		else
			data_dump
		end
	end

	def data_dump

		logger.notice "dumping data"

		require "xml"

		logger.time "dumping data" do

			@data_docs = {}
			@data_strs = {}

			FileUtils.remove_entry_secure "#{work_dir}/data" \
				if File.directory? "#{work_dir}/data"

			FileUtils.mkdir_p "#{work_dir}/data", :mode => 0700

			rows = couch.view("root", "by_type")["rows"]
			values_by_type = Hash.new

			legacy = false

			rows.each do |row|

				if legacy

					type = row["value"]["mandar_type"]
					value = row["value"]

				else

					type = row["value"]["type"]
					value = row["value"]["value"]

					row["id"] =~ /^current\/(.+)$/
					value["_id"] = $1

				end

				values_by_type[type] ||= Hash.new
				values_by_type[type][value["_id"]] = value

				main.continue

			end

			change =
				staged_change

			schemas_elem.find("schema").each do |schema_elem|
				schema_name = schema_elem.attributes["name"]

				values = values_by_type[schema_name] || Hash.new

				data_doc = XML::Document.new
				data_doc.root = XML::Node.new "data"

				if change
					change["items"].each do |key, item|
						case item["action"]
						when "create", "update"
							next unless key =~ /^#{Regexp.quote schema_name}\//
							values[key] = item["record"]
						when "delete"
							values.delete key
						else
							raise "Error"
						end
					end
				end

				sorted_values = values.values.sort { |a,b| a["_id"] <=> b["_id"] }
				sorted_values.each do |value|
					data_doc.root << js_to_xml(schemas_elem, schema_elem, value)
				end

				data_str = data_doc.to_s

				File.open "#{work_dir}/data/#{schema_name}.xml", "w" do |f|
					f.print data_str
				end

				@data_docs[schema_name] = data_doc
				@data_strs[schema_name] = data_str
			end

		end

	end

	def data_load

		logger.notice "loading data"

		require "xml"

		logger.time "loading data" do

			@data_docs = {}
			@data_strs = {}

			schemas_elem.find("schema").each do
				|schema_elem|

				schema_name =
					schema_elem.attributes["name"]

				data_path =
					"#{work_dir}/data/#{schema_name}.xml"

				if File.exist? data_path

					data_doc =
						XML::Document.file \
							data_path,
							:options => XML::Parser::Options::NOBLANKS

					data_str =
						data_doc.to_s

				else

					data_doc =
						XML::Document.string \
							"<data/>",
							:options => XML::Parser::Options::NOBLANKS

				end

				@data_docs[schema_name] = data_doc
				@data_strs[schema_name] = data_str

			end

		end

	end

	def schemas_elem

		return @schemas_elem \
			if @schemas_elem

		schemas_doc =
			XML::Document.file \
				"#{work_dir}/schema.xml",
				:options => XML::Parser::Options::NOBLANKS

		@schemas_elem =
			schemas_doc.root

		return @schemas_elem

	end

	def field_to_xml schemas_elem, fields_elem, value, elem

		value = {} unless value.is_a? Hash
		fields_elem.find("* [name() != 'option']").each do |field_elem|
			field_name = field_elem.attributes["name"]
			case field_elem.name
			when "text", "int", "ts-update", "enum"
				elem.attributes[field_name] = value[field_name].to_s
			when "bigtext"
				prop = XML::Node.new field_name
				prop << value[field_name]
				elem << prop
			when "bool"
				elem.attributes[field_name] = "yes" if value[field_name]

			when "list"
				items = value[field_name]
				if items.is_a? Array
					items.each do |item|
						prop = XML::Node.new field_name
						field_to_xml schemas_elem, field_elem, item, prop
						elem << prop
					end
				end

			when "struct"
				prop = XML::Node.new field_name
				field_to_xml schemas_elem, field_elem, value[field_name], prop
				elem << prop if prop.attributes.length + prop.children.size > 0
			when "xml"
				prop = XML::Node.new field_name
				temp_doc = XML::Document.string "<xml>#{value[field_name]}</xml>", :options =>XML::Parser::Options::NOBLANKS
				temp_doc.root.each { |temp_elem| prop << temp_elem.copy(true) }
				elem << prop
			else
				raise "unexpected element #{field_elem.name} found in field "
					"list for schema #{schema_elem.attributes["name"]}"
			end
		end
		if value["content"].is_a? Array
			value["content"].each do |item|
				item_type = item["type"]
				item_value = item["value"]
				option_elem = fields_elem.find_first("option [@name = '#{item_type}']")
				next unless option_elem
				option_ref = option_elem.attributes["ref"]
				schema_option_elem = schemas_elem.find_first("schema-option [@name = '#{option_ref}']")
				next unless schema_option_elem
				schema_option_props_elem = schema_option_elem.find_first("props")
				prop = XML::Node.new item_type
				field_to_xml schemas_elem, schema_option_props_elem, item_value, prop
				elem << prop
			end
		end
	end

	def field_to_json schemas_elem, schema_elem, fields_elem, elem, value

		fields_elem.find("* [name() != 'option']").each do |field_elem|

			field_name = field_elem.attributes["name"]

			case field_elem.name

				when "text"

					value[field_name] = elem.attributes[field_name]

				when "int", "ts-update"

					temp = elem.attributes[field_name]

					value[field_name] = temp.empty? ? nil : temp.to_i

				when "list"

					value[field_name] = []

					elem.find("* [ name () = #{xp field_name} ]") \
						.each do |child_elem|

						prop = {}

						field_to_json \
							schemas_elem,
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
							schemas_elem,
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
				schemas_elem.find_first \
					"schema-option [@name = '#{option_ref}']"

			raise "Error" \
				unless schema_option_elem

			schema_option_props_elem =
				schema_option_elem.find_first "props"

			prop = {}

			field_to_json \
				schemas_elem,
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

	def js_to_xml schemas_elem, schema_elem, value

		elem =
			XML::Node.new schema_elem.attributes["name"]

		field_to_xml \
			schemas_elem,
			schema_elem.find_first("id"),
			value,
			elem

		field_to_xml \
			schemas_elem,
			schema_elem.find_first("fields"),
			value,
			elem

		return elem

	end

	def xml_to_json schemas_elem, schema_elem, elem

		value = {}

		field_to_json \
			schemas_elem,
			schema_elem,
			schema_elem.find_first("id"),
			elem,
			value

		field_to_json \
			schemas_elem,
			schema_elem,
			schema_elem.find_first("fields"),
			elem,
			value

		return value
	end

	def staged_change

		return nil \
			unless $deploy_mode == :staged

		locks =
			couch.get "mandar-locks"

		return nil \
			unless locks

		change =
			locks["changes"][$deploy_role]

		return nil \
			unless change

		return change

	end

end
end
end
