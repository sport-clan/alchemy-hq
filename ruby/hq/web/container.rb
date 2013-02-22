module HQ
module Web
class Container

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

		@hq_apps =
			@config_elem
				.find("app")
				.to_a
				.map { |app_elem| init_app app_elem }

	end

	def init_app app_elem

		return {

			pattern:
				Regexp.new("^#{app_elem.attributes["pattern"]}$"),

			params:
				app_elem.find("param").to_a \
					.map {
						|param_elem|
						param_elem.attributes["name"]
					},

			provider:
				get_provider(app_elem)

		}

	end

	def handle env

		$stdout.sync = true
		$stderr.sync = true

		# iterate all apps

		@hq_apps.each do |app|

			# find app which matches path

			match =
				app[:pattern].match env["PATH_INFO"]

			next unless match

			# create hash from params

			params = Hash[
				app[:params].each_with_index.map { |name, index|
					[ name.to_sym, match[index + 1] ]
				}
			]

			# call that app's provider

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

		require \
			app_elem.attributes["require"]

		provider_class =
			eval app_elem.attributes["class"]

		provider =
			provider_class.get_provider app_elem

		return provider

	end

end
end
end
