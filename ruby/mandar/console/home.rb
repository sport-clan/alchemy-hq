class Mandar::Console::Home

	include Mandar::Console::Render
	include Mandar::Console::Utils

	def handle

		page = {
			_type: :console_page,
			_title: "Home",
		}

		all_schemas =
			config.find("schema").to_a

		my_schemas =
			all_schemas.select do |schema|
				can \
					[ "record-type", schema.attributes["name"] ],
					[ "read-only", "*" ]
			end

		my_schemas.sort! do |a, b|
			a.attributes["name"] <=> b.attributes["name"]
		end

		unless my_schemas.empty?

			page[:types] = {
				_type: :section,
				_heading: "Data types",
				_class: :data_types,

				list_div: {
					_type: :div,
					_class: :list_div,

					list: {
						_type: :unordered_list,
						data: my_schemas.to_a.map { |schema|
							schema_name = schema.attributes["name"]
							{
								_type: :link,
								_label: schema_name,
								_href: "/type/list/#{schema_name}",
							}
						},
					}
				},
			}

		end

		render page
	end
end
