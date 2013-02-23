module HQ
module Console
class ConsoleConfigCommand

	attr_accessor :hq

	def config() hq.config end
	def config_dir() hq.config_dir end
	def engine() hq.engine end
	def logger() hq.logger end
	def profile() hq.profile end

	def go command_name

		require "hq/tools/random"
		require "xml"

		hq.hostname = "console"

		#Mandar::Core::Config.rebuild_abstract

		logger.notice "creating console config"

		abstract =
			engine.abstract

		console_config =
			config.find_first "console"

		# create console-config.xml

		doc = XML::Document.new

		doc.root = XML::Node.new "console-config"

		doc.root["database-host"] = profile["database-host"]
		doc.root["database-port"] = profile["database-port"]
		doc.root["database-name"] = profile["database-name"]
		doc.root["database-user"] = profile["database-user"]
		doc.root["database-pass"] = profile["database-pass"]
		doc.root["mq-host"] = profile["mq-host"]
		doc.root["mq-port"] = profile["mq-port"]
		doc.root["mq-vhost"] = profile["mq-vhost"]
		doc.root["mq-user"] = profile["mq-user"]
		doc.root["mq-pass"] = profile["mq-pass"]
		doc.root["deploy-command"] = "#{config_dir}/.stubs/#{File.basename $0}"
		doc.root["deploy-profile"] = $profile
		doc.root["admin-group"] = console_config["admin-group"]
		doc.root["path-prefix"] = ""
		doc.root["http-port"] = "8080"
		doc.root["url-prefix"] = "http://localhost:8080"

		security_elem = XML::Node.new "security"
		security_elem["secret"] = Tools::Random.lower_case
		doc.root << security_elem

		web_socket_elem = XML::Node.new "web-socket"
		web_socket_elem["port"] = "8181"
		web_socket_elem["prefix"] = "ws://localhost:8181"
		web_socket_elem["secure"] = "no"
		doc.root << web_socket_elem

		[
			[ "grapher-config", [ ] ],
			[ "grapher-graph", "name" ],
			[ "grapher-graph-template", "name" ],
			[ "grapher-scale", "name" ],
			[ "role", "name" ],
			[ "role-member", [ "role", "member" ] ],
			[ "schema", "name" ],
			[ "schema-option", "name" ],
			[ "permission", [ "type", "subject" ] ],
		].each do
			|name, sort_by|

			elems = abstract[name].to_a

			sort_by = [ sort_by ].flatten

			elems.sort! do |elem_a, elem_b|

				sort_a = sort_by.map {
					|attr_name|
					elem_a.attributes[attr_name]
				}

				sort_b = sort_by.map {
					|attr_name|
					elem_a.attributes[attr_name]
				}

				sort_a <=> sort_b

			end

			elems.each do |elem|
				doc.root << doc.import(elem)
			end

		end

		File.open "#{config_dir}/etc/console-config.xml", "w" do
			|file|
			file.puts doc.to_s
		end

		logger.notice "done"

	end

end
end
end
