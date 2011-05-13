module Mandar::Console::Table

	def console_table type_elem, values, links = {}

		ret = {
			_type: :table,
			_columns: {},
			_data: {},
		}

		type_elem.find("table/col").each do |col_elem|
			col_name = col_elem.attributes["name"]
			col_label = col_elem.attributes["label"] || col_name
			ret[:_columns][col_name.to_s.to_sym] = {
				_type: :column,
				_label: col_label,
				_mode: :text,
			}
		end
		links.each do |link_name, link_fn|
			ret[:_columns][link_name.to_s.to_sym] = {
				_type: :column,
				_label: link_name,
				_mode: :render,
			}
		end

		values.each_with_index do |value, i|
			row = {}

			type_elem.find("table/col").each do |col_elem|
				col_name = col_elem.attributes["name"]
				field_elem = type_elem.find_first("(id|fields)/*[@name=#{xp col_name}]")
				next unless field_elem
				row[col_name.to_s.to_sym] = case field_elem.name
					when "ts-update" then to_ymd_hms value[col_name]
					when "bool" then value[col_name] ? "yes" : "no"
					else value[col_name]
				end
			end

			links.each do |link_name, link_fn|
				row[link_name.to_s.to_sym] = make_link link_fn.call(value), link_name
			end

			ret[:_data][i.to_s.to_sym] = row
		end

		return ret

	end

end
