class Mandar::AWS::Client

	attr_accessor :default_prefix

	def initialize(account, endpoint, version)
		@account = account
		@endpoint = endpoint
		@version = version
	end

	def aws_invoke(method, options = {})

		options[:action] = sym_to_aws(method)
		options[:version] = @version
		options[:AWS_access_key_id] = @account.access_key_id
		options[:timestamp] = Time.now.gmtime.strftime "%Y-%m-%dT%H:%M:%SZ"
		options[:signature_method] = "HmacSHA256"
		options[:signature_version] = "2"

		params = options_to_params(options)
		query_string = params_to_signed_query_string(params)

		require "net/http"
		require "net/https"
		unless @http
			@http = Net::HTTP.new @endpoint, 443
			@http.use_ssl = true
			@http.verify_mode = OpenSSL::SSL::VERIFY_PEER
			@http.verify_depth = 5
			@http.ca_path = "/etc/ssl/certs"
		end
		response = @http.post("/", query_string)

		require "xml"
		doc = XML::Document.string response.body, :options => XML::Parser::Options::NOBLANKS

		if doc.root.name == "Response"
			raise doc.find_first("Errors/Error/Message").content
		end

		doc.root.namespaces.default_prefix = @default_prefix if @default_prefix
		return doc
	end

	def method_missing(method, options = {})
		return aws_invoke method, options
	end

	def options_to_params(options)
		params = {}
		options.each do |key, value|
			collect_params(params, key, value)
		end
		return params
	end

	def collect_params(params, key, value)
		key = sym_to_aws(key)

		case value

		when String
			params[key] = value

		when Fixnum
			params[key] = value.to_s

		when TrueClass, FalseClass
			params[key] = value.to_s

		when Array
			value.each_with_index do |item, i|
				collect_params(params, "#{key}.#{i + 1}", item)
			end

		when Hash
			value.each do |hash_key, hash_value|
				hash_key = sym_to_aws(hash_key)
				collect_params(params, "#{key}.#{hash_key}", hash_value)
			end

		else
			raise "Don't know what to do with #{value.class}"

		end
	end

	def params_to_signed_query_string(params_hash)

		params_sorted = params_hash.sort { |a, b| a[0] <=> b[0] }
		params_string = params_sorted.map { |pair| urlenc(pair[0]) + "=" + urlenc(pair[1]) }.join("&")

		string_to_sign = "POST\n#{@endpoint}\n/\n#{params_string}"

		require "hmac-sha2"
		require "base64"
		hmac = HMAC::SHA256.digest(@account.secret_access_key, string_to_sign)
		hmac_b64 = Base64.encode64(hmac).chop

		params_hash["Signature"] = hmac_b64

		params_sorted = params_hash.sort { |a, b| a[0] <=> b[0] }
		params_string = params_sorted.map { |pair| urlenc(pair[0]) + "=" + urlenc(pair[1]) }.join("&")

		return params_string
	end

	def urlenc(str)
		return str.gsub(/[^-a-zA-Z0-9_.~]/) { |ch| "%%%02X" % ch[0] }
	end

	def sym_to_aws(sym)
		return sym if sym.is_a? String
		return sym.to_s.split("_").map { |str| str[0...1].upcase + str[1..-1] }.join("")
	end

end
