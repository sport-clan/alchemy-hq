
require "net/http"
require "net/https"
require "resolv"
require "set"

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
				{ :name => :warning, :required => true, :convert => :to_f },
				{ :name => :critical, :required => true, :convert => :to_f },
				{ :name => :url, :required => true },
				{ :name => :regex },
				{ :name => :timeout, :convert => :to_f },
				{ :name => :username },
				{ :name => :password },
			]

		@args.empty? or raise "Extra args on command line"

	end

	def perform_checks

		url = URI.parse @opts[:url]
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

				if @opts[:username]
					req.basic_auth @opts[:username], @opts[:password]
				end

				http = CustomHTTP.new url.host, url.port
				http.conn_address = address
				http.open_timeout = @opts[:timeout]
				http.read_timeout = @opts[:timeout]
				http.use_ssl = url.scheme == "https"
				http.start

				res = http.request req

				end_time = Time.now
				duration = end_time - start_time

				worst = duration if worst == nil
				worst = duration if duration > worst

				if res.code != "200"
					error_codes << res.code
				elsif @opts[:regex] && res.body !~ /#{@opts[:regex]}/
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

			if worst >= @opts[:critical]
				critical "#{worst}s time (critical is #{@opts[:critical]})"
			elsif worst >= @opts[:warning]
				warning "#{worst}s time (warning is #{@opts[:warning]})"
			else
				message "#{worst}s time"
			end
		end

	end

end
end
end
end
