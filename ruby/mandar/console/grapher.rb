class Mandar::Console::GrapherIndex

	include Mandar::Console::Utils

	def handle

		set_content_type "text/html"

		console_print "<title>Grapher Index</title>\n"

		console_print "<table>\n"
		config.find("grapher-graph").each do |graph_elem|
			graph_name = graph_elem.attributes["name"]
			console_print "<tr>\n"
			console_print "<td>#{graph_name}</td>\n"
			config.find("grapher-scale").each do |scale_elem|
				scale_name = scale_elem.attributes["name"]
				console_print "<td><a href=\"https://grapher.zattikka.com/graph/#{graph_name}/#{scale_name}\">#{scale_name}</td>\n"
			end
			console_print "</tr>\n"
		end
		console_print "</table>\n"

	end

end

class Mandar::Console::GrapherGraph

	include Mandar::Console::Utils

	def handle

		set_content_type "image/png"

		graph_name = get_vars["graph-name"]
		scale_name = get_vars["scale-name"]

		grapher_config_elem = config.find_first("grapher-config")
		rrd_database = grapher_config_elem.attributes["rrd-database"]

		graph_elem = config.find_first("grapher-graph[@name=#{xp graph_name}]")
		template_name = graph_elem.attributes["template"]

		graph_template_elem = config.find_first("grapher-graph-template[@name=#{xp template_name}]")

		scale_elem = config.find_first("grapher-scale[@name=#{xp scale_name}]")
		scale_steps = scale_elem.attributes["steps"].to_i
		scale_rows = scale_elem.attributes["rows"].to_i

		data = Mandar::Support::RRD.graph({
			:start => Time.now.to_i - scale_steps * scale_rows,
			:end => Time.now.to_i,
			:width => scale_rows,
			:height => 400,
			:data => graph_template_elem.find("data").map { |data_elem|
				{
					:name => data_elem.attributes["name"],
					:source_file => "#{rrd_database}/#{graph_elem.attributes["source"]}.rrd",
					:source_name => data_elem.attributes["source"],
					:source_function => data_elem.attributes["function"],
				}
			},
			:calc => graph_template_elem.find("calc").map { |calc_elem|
				{
					:name => calc_elem.attributes["name"],
					:rpn => calc_elem.attributes["rpn"],
				}
			},
			:outputs => graph_template_elem.find("output").map { |output_elem|
				{
					:type => output_elem.attributes["type"].upcase,
					:data => output_elem.attributes["data"],
					:colour => output_elem.attributes["colour"],
					:label => output_elem.attributes["label"],
					:stack => output_elem.attributes["stack"] == "yes",
				}
			},
		})

		console_print data

	end

end
