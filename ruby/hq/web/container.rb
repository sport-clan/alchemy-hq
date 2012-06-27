class HQ::Web::Container

	def initialize
	end

	def init config_path
		load_config config_path
		init_apps
	end

	def load_config config_path

		config_doc =
			XML::Document.file config_path

		config_elem =
			config_doc.root

		config_elem.name == "hq-web" \
			or raise "Error"

		@config_elem =
			config_elem
	end

	def init_apps

		hq_apps =
			@config_elem.find("app").to_a.map do |app_elem|
				{
					pattern: Regexp.new("^#{app_elem.attributes["pattern"]}$"),
					params: app_elem.find("param").to_a \
						.map { |param_elem|
							param_elem.attributes["name"]
						},
					provider: get_provider(app_elem)
				}
			end

		@hq_apps =
			hq_apps
	end

	def handle env

		$stdout.sync = true
		$stderr.sync = true

		@hq_apps.each do |app|
			match = app[:pattern].match env["PATH_INFO"]
			next unless match

			params = Hash[
				app[:params].each_with_index.map { |name, index|
					[ name.to_sym, match[index + 1] ]
				}
			]

			return app[:provider].call env, params
		end

		# default error page

		headers = {
			"Content-Type" => "text/html",
		}

		body = [
			"404 Not found",
		]

		return [ 404, headers, body ]
	end

	def get_provider app_elem

		case app_elem.attributes["provider"]

		when "grapher-graphs"

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
					HQ::Web::GrapherGraphs.new \
						grapher_config_elem

				handler.handle env, params

			end

		else
			raise "Error"

		end

	end

end
