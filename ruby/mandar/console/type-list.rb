class Mandar::Console::TypeList

	include Mandar::Console::Render
	include Mandar::Console::Table
	include Mandar::Console::Utils

	def handle

		forbidden unless is_admin

		type_name = get_vars["type_name"]
		type_elem = config.find_first("schema[@name=#{xp type_name}]") or not_found

		values = stager.get_all type_name, console_user

		sort_name = get_vars["sort"]
		if ! sort_name && sort_elem = type_elem.find_first("sort")
			sort_name = sort_elem.attributes["name"]
		end
		if sort_name
			sorts = type_elem.find("sort[@name=#{xp sort_name}]/col").to_a.map { |col| col.attributes["name"] }
			not_found if sorts.empty?
			values.sort! do |a, b|
				sorts.map { |sort| a[sort] } <=> sorts.map { |sort| b[sort] }
			end
		end

		render({
			_type: :console_page,
			_title: "List records of type '#{type_name}'",
			_links: {
				create: make_link("/type/edit/#{type_name}", "Create"),
			},
			sort: type_elem.find_first("sort") ? make_para(
				"Sort by ",
				type_elem.find("sort").to_a.map { |sort_elem|
					sort_name = sort_elem.attributes["name"]
					[ " | ", make_link("?sort=#{sort_name}", sort_name) ]
				}
			) : nil,
			data: console_table(type_elem, values, {
				edit: lambda { |value| "/type/edit/#{value["_id"]}" },
			}),
		})

	end
end
