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

	def self.xquery_client

		mandar = Mandar::Core::Config.mandar
		xquery_config = mandar.find_first "xquery"

		return false unless xquery_config

		require "ahq/xquery/client"

		xquery_client = \
			Ahq::Xquery::Client.new \
				xquery_config.attributes["url"]

		return xquery_client
	end

end
