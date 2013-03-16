require "net/http"
require "net/https"
require "resolv"
require "set"
require "xml"

require "hq/systools/monitoring/check-script.rb"
require "hq/tools/getopt"

module HQ
module SysTools
module Monitoring
class CheckSiteScript < CheckScript

	# custom http class allows us to connect to a different address

	class CustomHTTP < Net::HTTP
		attr_accessor :conn_address
	end

	def initialize
		super
		@name = "Site"
	end

	def process_args

		@opts, @args =
			Tools::Getopt.process @args, [
				{ :name => :config, :required => true },
			]

		@args.empty? or raise "Extra args on command line"

	end

	def prepare

		config_doc =
			XML::Document.file @opts[:config]

		@config_elem =
			config_doc.root

		@timings_elem =
			@config_elem.find_first "timings"

		@critical_time =
			@timings_elem["critical"].to_f

		@warning_time =
			@timings_elem["warning"].to_f

		@timeout_time =
			@timings_elem["timeout"].to_f

	end

	def perform_checks

		step_elem = @config_elem.find_first "step"
		request_elem = step_elem.find_first "request"
		response_elem = step_elem.find_first "response"

		url_str = "#{@config_elem["base-url"]}#{request_elem["path"]}"
		url = URI.parse url_str
		path = url.path
		path += "?#{url.query}" if url.query

		addresses = Resolv.getaddresses url.host

		worst = nil
		successes = 0
		failures = 0
		mismatches = 0
		error_codes = Set.new
		addresses.each do |address|
			req = nil
			begin

				start_time = Time.now

				req = Net::HTTP::Get.new path
				req["host"] = url.host
				req["user-agent"] = "mandar check_site"

				if request_elem["username"]
					req.basic_auth \
						request_elem["username"],
						request_elem["password"]
				end

				http = CustomHTTP.new url.host, url.port
				http.conn_address = address
				http.open_timeout = @timeout_time
				http.read_timeout = @timeout_time
				http.use_ssl = url.scheme == "https"
				http.start

				res = http.request req

				end_time = Time.now
				duration = end_time - start_time

				worst = duration if worst == nil
				worst = duration if duration > worst

				if res.code != "200"

					error_codes << res.code

				elsif response_elem["body-regex"] &&
					res.body !~ /#{response_elem["body-regex"]}/

					mismatches += 1

				else

					successes += 1

				end

			rescue Timeout::Error
				failures += 1

			end
		end

		errors = error_codes.size
		total = successes + errors + failures + mismatches

		if total == 0
			critical "unable to resolve #{url.host}"
		else
			message "#{total} hosts found"

			critical "#{failures} uncontactable" \
				if failures > 0

			critical "#{errors} errors (#{error_codes.to_a.join(",")})" \
				if errors > 0

			critical "#{mismatches} mismatches" \
				if mismatches > 0

			if worst != nil

				if worst >= @critical_time
					critical "#{worst}s time (critical is #{@critical_time})"
				elsif worst >= @warning_time
					warning "#{worst}s time (warning is #{@warning_time})"
				else
					message "#{worst}s time"
				end

			end

		end

	end

end
end
end
end
