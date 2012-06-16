module Mandar::Engine

	def self.xslt2_client

		return @xslt2_client if @xslt2_client

		mandar = Mandar::Core::Config.mandar
		xslt2_config = mandar.find_first "xslt2"

		return false unless xslt2_config

		@xslt2_client = Mandar::Engine::ConfigClient.new

		@xslt2_client.start

		return @xslt2_client
	end

	def self.xquery_server_start

		return if @xquery_server_started

		mandar = Mandar::Core::Config.mandar
		xquery_config = mandar.find_first "xquery"

		return false unless xquery_config

		xquery_port =
			xquery_config.attributes["port"]

		@xquery_url =
			"tcp://127.0.0.1:#{xquery_port}"

		rd, wr = IO.pipe

		xquery_server = "#{MANDAR}/c++/xquery-server"

		File.executable? xquery_server \
			or raise "Not found: #{xquery_server}"

		pid = fork do

			at_exit { exit! }

			rd.close

			pid = fork do

				at_exit { exit! }

				$stdin.reopen "/dev/null", "r"
				$stdout.reopen "/dev/null", "w"
				$stderr.reopen "/dev/null", "w"

				exec \
					xquery_server,
					@xquery_url
			end

			wr.puts pid
			wr.close

			exit!
		end

		wr.close
		pid = rd.gets.strip.to_i
		rd.close

		at_exit do
			Process.kill "TERM", pid
		end

		@xquery_server_started = true

	end

	def self.xquery_client

		xquery_server_start

		require "ahq/xquery/client"

		xquery_client = \
			Ahq::Xquery::Client.new \
				@xquery_url

		return xquery_client
	end

end
