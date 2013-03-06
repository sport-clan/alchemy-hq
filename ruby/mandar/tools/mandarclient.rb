class Mandar::Tools::MandarClient

	def initialize url, username, password
		require "multi_json"
		@url = URI.parse url
		@username = username
		@password = password
	end

	def http
		return @http if @http
		@http = Net::HTTP.new @url.host, @url.port
		@http.read_timeout = 60
		if @url.scheme == "https"
			@http.use_ssl = true
			@http.verify_mode = OpenSSL::SSL::VERIFY_PEER
			@http.verify_depth = 5
			@http.ca_path = "/etc/ssl/certs"
		end
		@http.start
		return @http
	end

	def call method, path, request_data = nil

		# prepare request

		request_string =
			request_data ? MultiJson.dump(request_data) : nil

		request =
			Net::HTTPGenericRequest.new \
				method,
				true,
				true,
				@url.path + path

		request.basic_auth \
			@username,
			@password

		request.body =
			request_string

		request["Content-Type"] =
			"application/json"

		# send request

		response =
			nil

		3.times do

			begin

				response =
					http.request request

				break

			rescue EOFError => e

				$stderr.puts "got error: #{e.message}"

				# reset connection

				http.finish
				@http = nil

				# and try again

				next

			end

		end

		# process response

		response_data =
			response["Content-Type"] == "application/json" \
				? MultiJson.load(response.body)
				: nil

		return response.code.to_i, response_data

	end

	def stager_get type, id = nil
		status, response = call "GET", id ? "/stager/data/#{type}/#{id}" : "/stager/data/#{type}"
		case status
			when 200 then return response
			when 404 then return nil
			else raise "Error #{status}"
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

	def rollback
		status, response = call "POST", "/stager/rollback", {}
		raise "error" unless status == 200
		return response
	end

	def cancel
		status, response = call "POST", "/stager/cancel", {}
		raise "error" unless status == 200
		return response
	end
end

