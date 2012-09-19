class Mandar::Console::TypeEdit

	include Mandar::Console::Forms
	include Mandar::Console::Render
	include Mandar::Console::Utils

	def handle

		# decode path

		type_name, part_id =
			get_vars["id"].split("/", 2)

		if part_id
			id =
				get_vars["id"]
		end

		# lookup schema

		type =
			config.find_first("schema[@name=#{xp type_name}]")

		# load object from database

		exist =
			id ? true : false

		row =
			exist ? stager.get(id, console_user) : {}

		raise "Not found" \
			unless row

		# check permissions

		can_read_write =
			can \
				[ "super", "*" ],
				[ "read-write", "*" ],
				[ "read-write", type_name ]

		can_read_only =
			can_read_write || can(
				[ "read-only", "*" ],
				[ "read-only", type_name ])

		forbidden \
			unless can_read_only

		forbidden \
			if request_method == :post && ! can_read_write

		forbidden \
			if ! exist && ! can_read_write

		# apply updates from post

		if request_method == :post

			locks =
				locks_man.load

			my_change =
				locks_man.my_change \
					locks,
					console_user,
					true

			post_vars["rev"] == row["_rev"] \
				or raise "Revision mismatch!"

			%W[ stage done ].include? my_change["state"] \
				or raise "Can't update records while a deploy is in progress"

			unless exist

				row =
					update_field_struct \
						type,
						type.find_first("id"),
						"id",
						post_vars,
						row

			end

			row =
				update_field_struct \
					type,
					type.find_first("fields"), \
					"field", \
					post_vars, \
					row

			if post_vars["create"]
				row["mandar_type"] = type_name
				row["_id"] = type_name + "/" + (
					type.find("id/*").to_a.map \
						{ |id_elem| row[id_elem.attributes["name"]] }
				).join("/")
				stager.create row, console_user
				redirect_see_other "/type/edit/#{type_name}"
			end

			if post_vars["update"]
				stager.update row, console_user
				redirect_see_other "/type/list/#{type_name}"
			end

			if post_vars["delete"]
				stager.delete row, console_user
				redirect_see_other "/type/list/#{type_name}"
			end

		end

		render({
			_type: :console_page,
			_title: exist ? "Edit record with id '#{id}'" : "Create new record of type '#{type_name}'",

			_links: {
				type: make_link("/type/list/#{type_name}", "List"),
				create: exist ? make_link("/type/edit/#{type_name}", "Create") : nil,
			},

			_notices: {
				who: ! [ nil, console_user ].include?(who = stager.who(id)) ?
					make_warning("This record is currently being edited by #{who}. Changes will not be possible.") : nil,
			},

			form: {
				_type: :form,
				_method: :post,

				buttons_0: buttons_0 = {
					_type: :buttonset,

					update: exist && can_read_write ?
						make_submit("update", "save changes") : nil,

					delete: exist && can_read_write ?
						make_submit("delete", "delete") : nil,

					create: ! exist ?
						make_submit("create", "create") : nil,
				},

				rev: make_hidden("rev", row["_rev"], 0),

				fields: {
					_type: :fields,

					id:
						create_field_struct_contents(
							type,
							type.find_first("id"),
							"id",
							row,
							0,
							exist),

					fields:
						create_field_struct_contents(
							type,
							type.find_first("fields"),
							"field",
							row,
							0,
							! can_read_write),
				},

				buttons_1: buttons_0,
			}
		})

	end

# ======================================== list field

	def create_field_list \
			type_elem,
			field_elem,
			path,
			value,
			depth,
			readonly

		field_name =
			field_elem.attributes["name"]

		field_max =
			field_elem.attributes["max"]

		value = [] \
			unless value.is_a? Array

		ret = []

		value.each_with_index do |item, i|

			item_path =
				"#{path}-#{i}"

			ret <<
				make_generic_field(
					field_name,
					depth,
					readonly ? {} : {
						add:
							make_submit(
								"#{item_path}--add",
								"add #{field_elem.attributes["name"]}"),
						remove:
							make_submit(
								"#{item_path}--remove",
								"remove #{field_name}"),
					})

			ret <<
				create_field_struct_contents(
					type_elem,
					field_elem,
					item_path,
					item,
					depth + 1,
					readonly)

		end

		if ! readonly && (! field_max || value.length < field_max.to_i)

			ret <<
				make_generic_field(
					"...",
					depth,
					{
						add:
							make_submit(
								"#{path}--add",
								"add #{field_elem.attributes["name"]}")
					})

		end

		ret <<
			make_hidden(
				"#{path}--count",
				value.length,
				depth)

		return ret

	end

	def update_field_list type_elem, field_elem, path, form, value
		value = []
		count = form["#{path}--count"].to_i
		count += 1 if form["#{path}--add"]
		count.times do |i|
			next if form["#{path}-#{i}--remove"]
			value << {} if form["#{path}-#{i}--add"]
			item = update_field_struct type_elem, field_elem, "#{path}-#{i}", form, {}
			value << item
		end
		return value
	end

# ======================================== text field

	def create_field_text type_elem, field_elem, path, value, depth, readonly
		return make_text_field path, field_elem.attributes["name"], value, depth, readonly
	end

	def update_field_text type_elem, field_elem, path, form, value
		return form[path].to_s
	end

# ======================================== bigtext field

	def create_field_bigtext type_elem, field_elem, path, value, depth, readonly
		return make_bigtext_field path, field_elem.attributes["name"], value, depth, readonly
	end

	def update_field_bigtext type_elem, field_elem, path, form, value
		return form[path].to_s.gsub("\r\n", "\n")
	end

# ======================================== xml field

	def create_field_xml type_elem, field_elem, path, value, depth, readonly
		return make_bigtext_field path, field_elem.attributes["name"], value, depth, readonly
	end

	def update_field_xml type_elem, field_elem, path, form, value
		return form[path].to_s
	end

# ======================================== bool field

	def create_field_bool type_elem, field_elem, path, value, depth, readonly
		return make_boolean_field path, field_elem.attributes["name"], value, depth, readonly
	end

	def update_field_bool type_elem, field_elem, path, form, value
		return form[path] == "on"
	end

# ======================================== int field

	def create_field_int type_elem, field_elem, path, value, depth, readonly
		return make_text_field path, field_elem.attributes["name"], value, depth, readonly
	end

	def update_field_int type_elem, field_elem, path, form, value
		return form[path].to_i
	end

# ======================================== struct field

	def create_field_struct type_elem, fields_elem, path, value, depth, readonly
		return {
			heading: make_generic_field(fields_elem.attributes["name"], depth, {}),
			contents: create_field_struct_contents(type_elem, fields_elem, path, value, depth + 1, readonly),
		}
	end

	def create_field_struct_contents \
			type_elem,
			fields_elem,
			path,
			value,
			depth,
			readonly

		value = {} \
			unless value.is_a? Hash

		return {
			fields: fields_elem.find("* [name() != 'option']").to_a.map { |field_elem|

				field_type =
					field_elem.name

				field_name =
					field_elem.attributes["name"]

				field_path =
					"#{path}-#{field_name}"

				field_value =
					value ? value[field_name] : nil

				if field_elem.attributes["secret"] == "yes" && readonly

					create_field_text \
						type_elem,
						field_elem,
						field_path,
						"********",
						depth,
						readonly

				else

					send \
						"create_field_#{field_type.gsub ?-, ?_}",
						type_elem,
						field_elem,
						field_path,
						field_value,
						depth,
						readonly

				end

			},
			options: fields_elem.find_first("option") ? {
				content: value && value["content"] && ! value["content"].empty? ?
					(0...value["content"].size).map { |i|
						item = value["content"][i]
						item_type = item["type"]
						item_path = "#{path}-#{i}"
						option_elem = fields_elem.find_first("option [@name = '#{item_type}']")
						next unless option_elem
						option_ref = option_elem.attributes["ref"]
						schema_option_elem = config.find_first("schema-option [@name = '#{option_ref}']")
						schema_option_elem or raise "Can't find <schema-option name=\"#{option_ref}\">"
						schema_option_props_elem =
							schema_option_elem.find_first("props")

						[

							make_hidden(
								"#{item_path}--type",
								item_type,
								depth),

							make_generic_field(
								item_type,
								depth,
								readonly ? nil : {
									adds:
										fields_elem.find("option").to_a.map { |option_elem|
											option_name =
												option_elem.attributes["name"]
											make_submit(
												"#{path}--add-#{option_name}-#{i}",
												"add #{option_name}")
										},
									remove:
										make_submit(
											"#{item_path}--remove",
											"remove #{item_type}"),
								}),

							struct:
								create_field_struct_contents(
									type_elem,
									schema_option_props_elem,
									item_path,
									item["value"],
									depth + 1,
									readonly),

						]

				} : nil,

				adds: readonly ? nil :

					make_generic_field(
						"...",
						depth,
						{
							buttons:
								fields_elem.find("option").to_a.map { |option_elem|
									option_name = option_elem.attributes["name"]
									make_submit("#{path}--add-#{option_name}", "add #{option_name}")
								},
						}),

				count:
					make_hidden(
						"#{path}--count",
						value && value["content"] && value["content"].size || 0,
						depth),

			} : nil,
		}
	end

	def update_field_struct type_elem, fields_elem, path, form, value
		value = {} unless value.is_a? Hash
		fields_elem.find("* [name() != 'option']").each do |field_elem|
			field_type = field_elem.name
			field_name = field_elem.attributes["name"]
			field_path = "#{path}-#{field_name}"
			value[field_name] = send "update_field_#{field_type.gsub ?-, ?_}", \
				type_elem, field_elem, field_path, form, value[field_name]
		end
		if fields_elem.find_first("option")
			old_content = value["content"] || []
			value["content"] = []
			count = (form["#{path}--count"] || 0).to_i
			(0...count).each do |i|
				fields_elem.find("option").each do |option_elem|
					option_name = option_elem.attributes["name"]
					if form["#{path}--add-#{option_name}-#{i}"]
						value["content"] << { "type" => option_name, "value" => {} }
					end
				end
				item_path = "#{path}-#{i}"
				next if form["#{item_path}--remove"]
				item_type = form["#{item_path}--type"]
				option_elem = fields_elem.find_first("option [@name = '#{item_type}']")
				next unless option_elem
				option_ref = option_elem.attributes["ref"]
				schema_option_elem = config.find_first("schema-option [@name = '#{option_ref}']")
				schema_option_props_elem = schema_option_elem.find_first("props")
				value["content"] << {
					"type" => item_type,
					"value" => send("update_field_struct", \
						type_elem, schema_option_props_elem, item_path, form,
						old_content[i] && old_content[i]["value"]),
				}
			end
			fields_elem.find("option").each do |option_elem|
				option_name = option_elem.attributes["name"]
				if form["#{path}--add-#{option_name}"]
					value["content"] << { "type" => option_name, "value" => {} }
				end
			end
		end
		return value
	end

# ======================================== ts update field

	def create_field_ts_update type_elem, field_elem, path, value, depth, readonly
		value_str = "%s (%s)" % [ to_ymd_hms(value), value ]
		return make_text_field path, field_elem.attributes["name"], value_str, depth, true
	end

	def update_field_ts_update type_elem, field_elem, path, form, value
		return Time.now.to_i
	end

end
