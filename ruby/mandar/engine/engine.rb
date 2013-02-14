module Mandar::Engine

	def self.xquery_client

		require "hq/xquery/client"

		Mandar.debug "starting xquery server"

		spec =
			Gem::Specification.find_by_name "alchemy-hq"

		xquery_server =
			"#{spec.gem_dir}/c++/xquery-server"

		client =
			HQ::XQuery.start xquery_server

		return client

	end

end
