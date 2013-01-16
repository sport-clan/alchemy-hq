require "hq/web"

# TODO get rid of this
require "mandar"

module HQ::Web::Grapher
end

class HQ::Web::Grapher::GraphHandler

	include Mandar::Tools::Escape

	def self.get_provider app_elem

		config_elem =
			app_elem.find_first "config"

		grapher_config_path =
			config_elem.attributes["path"]

		grapher_config_doc =
			XML::Document.file grapher_config_path

		grapher_config_elem =
			grapher_config_doc.root

		return proc do |env, params|

			handler =
				HQ::Web::Grapher::GraphHandler.new \
					grapher_config_elem

			handler.handle \
				env,
				params

		end

	end

	def initialize config_elem
		@config_elem = config_elem
	end

	def handle env, params

		graph_name = params[:name]
		scale_name = params[:scale]

		rrd_database =
			@config_elem.attributes["database-path"]

		graph_elem =
			@config_elem.find_first("
				graph [@name = #{xp graph_name}]
			")

		template_name =
			graph_elem.attributes["template"]

		template_elem =
			@config_elem.find_first("
				template [@name = #{xp template_name}]
			")

		scale_elem =
			@config_elem.find_first("
				scale [@name = #{xp scale_name}]
			")

		scale_steps = scale_elem.attributes["steps"].to_i
		scale_rows = scale_elem.attributes["rows"].to_i

		data = Mandar::Support::RRD.graph({
			:start => Time.now.to_i - scale_steps * scale_rows,
			:end => Time.now.to_i,
			:width => scale_rows,
			:height => 400,
			:data => template_elem.find("data").map { |data_elem|
				{
					:name => data_elem.attributes["name"],
					:source_file => "#{rrd_database}/#{graph_elem.attributes["source"]}.rrd",
					:source_name => data_elem.attributes["source"],
					:source_function => data_elem.attributes["function"],
				}
			},
			:calc => template_elem.find("calc").map { |calc_elem|
				{
					:name => calc_elem.attributes["name"],
					:rpn => calc_elem.attributes["rpn"],
				}
			},
			:outputs => template_elem.find("output").map { |output_elem|
				{
					:type => output_elem.attributes["type"].upcase,
					:data => output_elem.attributes["data"],
					:colour => output_elem.attributes["colour"],
					:label => output_elem.attributes["label"],
					:stack => output_elem.attributes["stack"] == "yes",
				}
			},
		})

		headers = {
			"Content-Type" => "image/png"
		}

		body = [
			data
		]

		return [ 200, headers, body ]
	end
end
