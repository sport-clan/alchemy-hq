class Mandar::Console::Server

	include Mandar::Console::Utils

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

		entropy = Mandar::Console::Entropy.new
		app_ctx[:entropy] = entropy

		db_host = config.attributes["database-host"]
		db_port = config.attributes["database-port"]
		db_name = config.attributes["database-name"]
		db_user = config.attributes["database-user"]
		db_pass = config.attributes["database-pass"]
		couch_server = Mandar::CouchDB::Server.new(db_host, db_port)
		couch_server.auth db_user, db_pass
		db = couch_server.database(db_name)
		app_ctx[:db] = db

		locks_man = Mandar::Console::LocksManager.new
		locks_man.db = db
		app_ctx[:locks_man] = locks_man

		stager = Mandar::Console::Stager.new
		stager.db = db
		stager.entropy = entropy
		stager.locks_man = locks_man
		app_ctx[:stager] = stager

		api_handler = Mandar::Console::ApiHandler.new
		app_ctx[:api_handler] = api_handler

		console_handler = Mandar::Console::ConsoleHandler.new
		app_ctx[:console_handler] = console_handler

		proc_handler = MyProcHandler.new do |req, resp|

			WEBrick::HTTPAuth.basic_auth req, resp, "Config console" do |user, pass|
				if user then
					role = config.find_first "role[@name=#{xp user}]"
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

		http_server.start

	end

end
