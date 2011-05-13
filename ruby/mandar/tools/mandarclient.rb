class Mandar::Tools::MandarClient

	def initialize url, username, password
		@url = URI.parse url
		@username = username
		@password = password
	end

	def http
		return @http if @http
		@http = Net::HTTP.start @url.host, @url.port
		@http.read_timeout = 300
		return @http
	end

	def call(method, path, request_data = nil)
		request_string = request_data ? JSON.generate(request_data) : nil
		request = Net::HTTPGenericRequest.new(method, true, true, @url.path + path)
		request.basic_auth @username, @password
		request.body = request_string
		request["Content-Type"] = "application/json"
		response = http.request(request)
		response_data = response["Content-Type"] == "application/json" ? JSON.parse(response.body) : nil
		return response.code.to_i, response_data
	end

	def stager_get type, id = nil
		status, response = call "GET", id ? "/stager/data/#{type}/#{id}" : "/stager/data/#{type}"
		case status
			when 200 then return response
			when 404 then return nil
			else raise "Error"
		end
	end

	def stager_create type, record
		status, response = call "POST", "/stager/data/#{type}", record
		raise "error" unless status == 200
		return response
	end

	def stager_update type, id, record
		status, response = call "PUT", "/stager/data/#{type}/#{id}", record
		raise "error" unless status == 200
		return response
	end

	def stager_delete type, id, record
		status, response = call "DELETE", "/stager/data/#{type}/#{id}", record
		raise "error" unless status == 200
		return response
	end

	def types
		status, response = call "GET", "/stager/data"
		raise "error" unless status == 200
		return response
	end

	def deploy
		status, response = call "POST", "/stager/deploy", {}
		raise "error" unless status == 200
		return response
	end

	def commit
		status, response = call "POST", "/stager/commit", {}
		raise "error" unless status == 200
		return response
	end

	def stager_cancel
		status, response = call "POST", "/stager/cancel", {}
		raise "error" unless status == 200
		return response
	end
end
