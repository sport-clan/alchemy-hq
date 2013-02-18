require  "hq/couchdb"

module HQ
module CouchDB
class Database

	def initialize server, db
		@server = server
		@db = db
	end

	def create doc
		path = CouchDB.urlf("/%", @db)
		return @server.call("POST", path, doc)
	end

	def get id
		path = CouchDB.urlf("/%/%", @db, id)
		return @server.call("GET", path)
	end

	def get_nil id
		begin
			return get id
		rescue CouchNotFoundException
			return nil
		end
	end

	def update doc

		path =
			CouchDB.urlf \
				"/%/%",
				@db,
				doc["_id"]

		return @server.call "PUT", path, doc

	end

	def delete id, rev

		path =
			CouchDB.urlf \
				"/%/%?rev=%",
				@db,
				id,
				rev

		return @server.call "DELETE", path

	end

	def view design, view

		path =
			CouchDB.urlf \
				"/%/_design/%/_view/%",
				@db,
				design,
				view

		return @server.call "GET", path

	end

	def view_key design, view, key

		path =
			CouchDB.urlf \
				"/%/_design/%/_view/%?key=%",
				@db,
				design,
				view,
				key.to_json

		return @server.call "GET", path

	end

	def bulk docs

		path =
			CouchDB.urlf \
				"/%/_bulk_docs",
				@db

		return @server.call "POST", path, { "docs" => docs }

	end

	def all_docs

		path =
			CouchDB.urlf \
				"/%/_all_docs",
				@db

		return @server.call "GET", path

	end

end
end
end
