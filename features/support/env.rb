require "yaml"

HQ_DIR =
	File.expand_path \
		"#{File.dirname __FILE__}/../.."

$LOAD_PATH.unshift \
	"#{HQ_DIR}/ruby"

def xquery_client

	return @xquery_client \
		if @xquery_client

	require "hq/xquery"

	@xquery_client =
		HQ::XQuery.start \
			"#{HQ_DIR}/c++/xquery-server"

	return @xquery_client

end

def xquery_session

	return @xquery_session ||=
		xquery_client.session

end

def mvcc

	require "hq/engine/mvcc"

	return @mvcc \
		if @mvcc

	mvcc =
		HQ::Engine::MVCC.new

	return @mvcc =
		mvcc

end

def public_api

	require "hq/engine/api"

	return @oublic_api \
		if @publiC_api

	public_api =
		HQ::Engine::API.new

	public_api.mvcc =
		mvcc

	return @public_api =
		public_api

end

After do
	if @xquery_client
		@xquery_client.close
		@xquery_client = nil
	end
end
