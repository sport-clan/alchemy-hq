require "webrick"

module Mandar
module Console
class Server

	include Utils

    class MyProcHandler < WEBrick::HTTPServlet::AbstractServlet

		def get_instance server, *options
			self
		end

		def initialize &proc
			@proc = proc
		end

		def do_GET request, response
			@proc.call request, response
		end

		alias do_POST do_GET
		alias do_PUT do_GET
		alias do_DELETE do_GET
    end

	def run

		app_ctx = {}

		config_doc = XML::Document.file "#{CONFIG}/etc/console-config.xml"
		config = config_doc.root
		app_ctx[:config] = config

		app_ctx[:element_indent] = "  "

		entropy = Entropy.new
		app_ctx[:entropy] = entropy

		db_host = config.attributes["database-host"]
		db_port = config.attributes["database-port"]
		db_name = config.attributes["database-name"]
		db_user = config.attributes["database-user"]
		db_pass = config.attributes["database-pass"]
		require "hq/couchdb/couchdb-server"
		couch_server = HQ::CouchDB::Server.new(db_host, db_port)
		couch_server.logger = Mandar.logger
		couch_server.auth db_user, db_pass
		db = couch_server.database(db_name)
		app_ctx[:db] = db

		locks_man = LocksManager.new
		locks_man.db = db
		app_ctx[:locks_man] = locks_man

		api_handler = ApiHandler.new
		app_ctx[:api_handler] = api_handler

		console_handler = ConsoleHandler.new
		app_ctx[:console_handler] = console_handler

		# event machine

		require "hq/core/event-machine-thread-wrapper"

		em_wrapper = HQ::Core::EventMachineThreadWrapper.new
		em_wrapper.start

		# message queue

		require "hq/mq/mq-wrapper"

		mq_wrapper = HQ::MQ::MqWrapper.new
		mq_wrapper.em_wrapper = em_wrapper
		mq_wrapper.host = config["mq-host"]
		mq_wrapper.port = config["mq-port"]
		mq_wrapper.vhost = config["mq-vhost"]
		mq_wrapper.username = config["mq-user"]
		mq_wrapper.password = config["mq-pass"]
		mq_wrapper.start

		app_ctx[:mq_wrapper] = mq_wrapper

		# web sockets

		require "em-websocket"

		console_web_socket_handler =
			ConsoleWebSocketHandler.new

		console_web_socket_handler.app_ctx =
			app_ctx

		app_ctx[:console_web_socket_handler] =
			console_web_socket_handler

		em_wrapper.quick do

			web_socket_config =
				config.find_first("web-socket")

			opts = {
				host: "0.0.0.0",
				port: web_socket_config["port"].to_i,
				secure: web_socket_config["secure"] == "yes",
				tls_options: {
					private_key_file: web_socket_config["private-key-file"],
					cert_chain_file: web_socket_config["cert-chain-file"],
				},
			}
require "pp"
pp opts

			EventMachine::WebSocket.run opts do
				|web_socket|
puts "RUNNING"
puts web_socket.state

				console_web_socket_handler.handle \
					web_socket

			end

		end

		# stager

		stager = Stager.new
		stager.config = config
		stager.db = db
		stager.em_wrapper = em_wrapper
		stager.entropy = entropy
		stager.locks_man = locks_man
		stager.mq_wrapper = mq_wrapper
		app_ctx[:stager] = stager

		# request handler

		proc_handler = MyProcHandler.new do |req, resp|

			WEBrick::HTTPAuth.basic_auth req, resp, "Config console" do
				|user, pass|

				if user then
					role = config.find_first "role[@name=#{xp user}]"
					if role then
						expect = role.attributes["password-crypt"]
						salt = expect.split("$")[2]
						crypt = pass.crypt "$6$#{salt}$"
						if crypt == expect
							req.attributes[:user] = user
							true
						else
							false
						end
					else
						false
					end
				else
					false
				end

			end

			req_ctx = {}

			req_ctx[:element_indent_current] = ""

			req_ctx[:req] = req
			req_ctx[:resp] = resp

			Thread.current[:app_ctx] = app_ctx
			Thread.current[:req_ctx] = req_ctx

			catch :mandar_abort_request do

				req.path =~ /^#{Regexp.escape config.attributes["path-prefix"]}(.*)$/ \
					or not_found
				path = $1

				console_handler.handle path

			end

		end

		# http server

		http_server_config = {}

		http_server_config[:Port] =
			config.attributes["http-port"].to_i

		http_server =
			WEBrick::HTTPServer.new \
				http_server_config

		http_server.mount "/", proc_handler

		%W[ INT TERM ].each do |signal|
			trap signal do
				http_server.shutdown
			end
		end

		# main loop

		http_server.start

		# shut down message queue

		mq_wrapper.stop

		# shut down event machine

		em_wrapper.stop

	end

end
end
end
