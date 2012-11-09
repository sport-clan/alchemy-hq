module Mandar::Engine

	def self.xquery_client

		require "hq/xquery/client"

		Mandar.debug "starting xquery server"

		client =
			HQ::XQuery.start \
				"#{CONFIG}/alchemy-hq/c++/xquery-server"

		return client

	end

end
