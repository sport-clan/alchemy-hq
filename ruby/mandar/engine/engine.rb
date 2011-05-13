module Mandar::Engine

	def self.zorba
		return @zorba if @zorba
		return nil unless defined? Zorba_api

		Mandar.debug "initialising zorba xquery library"
		start_time = Time.now

		store = Zorba_api::InMemoryStore.getInstance()
		@zorba = Zorba_api::Zorba.getInstance(store)

		end_time = Time.now
		Mandar.trace "initialising zorba xquery library took #{((end_time - start_time) * 1000).to_i}ms"

		return @zorba
	end

	def self.data_manager
		return zorba ? zorba.getXmlDataManager() : nil
	end

	def self.config_client
		return @config_client if @config_client
		@config_client = Mandar::Engine::ConfigClient.new
		@config_client.start
		return @config_client
	end

end
