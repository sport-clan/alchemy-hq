require "hq/couchdb"

module HQ
module CouchDB
class Server

	attr_accessor :logger

	def initialize hostname = "localhost", port = 5984

		require "cgi"
		require "multi_json"
		require "net/http"

		@hostname = hostname
		@port = port

	end

	def auth username, password
		@username = username
		@password = password
	end

	def version
		path = CouchDB.urlf "/"
		return call "GET", path
	end

	def all
		path = CouchDB.urlf "/_all_dbs"
		return call "GET", path
	end

	def create db
		path = CouchDB.urlf "/%", db
		return call "PUT", path
	end

	def get db
		path = CouchDB.urlf "/%", db
		return call "GET", path
	end

	def temp_view db, code
		path = CouchDB.urlf "/%/_temp_view", db
		return call "POST", path, code
	end

	def call method, path, request = nil

		request_string =
			request ? MultiJson.dump(request) : nil

		response_string =
			http_request \
				method,
				path,
				request_string

		response =
			MultiJson.load response_string

		if response.is_a?(Hash) && response["error"]
			raise CouchDB::map_error response
		end

		return response
	end

	def http_request method, path, request_string
		logger.trace "couchdb #{method} #{path} #{request_string}"
		# TODO reuse connections
		Net::HTTP.start @hostname, @port do |http|
			request = Net::HTTPGenericRequest.new(method, true, true, path)
			request.basic_auth @username, @password
			request.body = request_string
			request["Content-Type"] = "application/json"
			response = http.request(request)
			return response.body
		end
	end

	def database name
		require "hq/couchdb/database"
		return CouchDB::Database.new(self, name)
	end

end
end
end
