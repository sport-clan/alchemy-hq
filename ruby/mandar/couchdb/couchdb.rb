module Mandar::CouchDB

	def self.urlf(url, *args)
		ret = ""
		url.each_char do |char|
			if char != "%"
				ret << char
				next
			end
			z = args.unshift
			ret << CGI::escape(args.shift)
		end
		return ret
	end

	class CouchException < Exception
	end

	class CouchNotFoundException < CouchException
	end

	def self.map_error response
		error = response["error"]
		reason = response["reason"]
		return case error
		when "not_found"
			CouchNotFoundException.new "CouchDB error: #{error}: #{reason}"
		else
			CouchException.new "CouchDB error: #{error}: #{reason}"
		end
	end

	class Server

		def initialize(hostname = "localhost", port = 5984)
			require "cgi"
			require "json"
			require "net/http"
			@hostname = hostname
			@port = port
		end

		def auth(username, password)
			@username = username
			@password = password
		end

		def version()
			path = Mandar::CouchDB.urlf("/")
			return call("GET", path)
		end

		def all()
			path = Mandar::CouchDB.urlf("/_all_dbs")
			return call("GET", path)
		end

		def create(db)
			path = Mandar::CouchDB.urlf("/%", db)
			return call("PUT", path)
		end

		def get(db)
			path = Mandar::CouchDB.urlf("/%", db)
			return call("GET", path)
		end

		def temp_view(db, code)
			path = Mandar::CouchDB.urlf("/%/_temp_view", db)
			return call("POST", path, code)
		end

		def call(method, path, request = nil)

			request_string = request ? JSON.generate(request, :max_nesting => false) : nil

			response_string = http_request(method, path, request_string)

			response = JSON.parse(response_string, :max_nesting => false)

			if response.is_a?(Hash) && response["error"]
				raise Mandar::CouchDB::map_error response
			end

			return response
		end

		def http_request(method, path, request_string)
			Mandar.debug "couchdb #{method} #{path} #{request_string}"
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

		def database(name)
			return Database.new(self, name)
		end

	end

	class Database

		def initialize(server, db)
			@server = server
			@db = db
		end

		def create(doc)
			path = Mandar::CouchDB.urlf("/%", @db)
			return @server.call("POST", path, doc)
		end

		def get(id)
			path = Mandar::CouchDB.urlf("/%/%", @db, id)
			return @server.call("GET", path)
		end

		def get_nil(id)
			begin
				return get id
			rescue CouchNotFoundException
				return nil
			end
		end

		def update(doc)
			path = Mandar::CouchDB.urlf("/%/%", @db, doc["_id"])
			return @server.call("PUT", path, doc)
		end

		def delete(id, rev)
			path = Mandar::CouchDB.urlf("/%/%?rev=%", @db, id, rev)
			return @server.call("DELETE", path)
		end

		def view(design, view)
			path = Mandar::CouchDB.urlf("/%/_design/%/_view/%", @db, design, view)
			return @server.call("GET", path)
		end

		def view_key(design, view, key)
			path = Mandar::CouchDB.urlf("/%/_design/%/_view/%?key=%", @db, design, view, key.to_json)
			return @server.call("GET", path)
		end

		def bulk docs
			path = Mandar::CouchDB.urlf \
				"/%/_bulk_docs", \
				@db
			return @server.call "POST", path, { "docs" => docs }
		end

		def all_docs
			path = Mandar::CouchDB.urlf \
				"/%/_all_docs", \
				@db
			return @server.call "GET", path
		end

	end
end
