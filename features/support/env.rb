require "yaml"
require "zmq"

require "ahq/xquery/client"

def xquery_client

	return @xquery_client if @xquery_client

	@xquery_client = Ahq::Xquery::Client.new "tcp://localhost:5555"

	return @xquery_client
end

After do
	if @xquery_client
		@xquery_client.close
		@xquery_client = nil
	end
end
