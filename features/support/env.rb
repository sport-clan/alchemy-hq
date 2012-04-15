require "yaml"
require "zmq"

require "ahq/xquery/client"

def xquery_client
	return @xquery_client ||=
		Ahq::Xquery::Client.new("tcp://localhost:5555")
end

def xquery_session
	return @xquery_session ||=
		xquery_client.session
end

After do
	if @xquery_client
		@xquery_client.close
		@xquery_client = nil
	end
end
