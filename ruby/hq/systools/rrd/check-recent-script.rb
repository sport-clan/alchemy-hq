# parent
require "hq/systools/rrd"

# libraries
require "RRD"

# hq stuff
require "hq/systools/monitoring/check-script"
require "hq/tools/getopt"

class HQ::SysTools::RRD::CheckRecentScript \
	< HQ::SysTools::Monitoring::CheckScript

	def process_args

		@opts, @files =
			HQ::Tools::Getopt.process @args, [

				{ :name => :warning,
					:required => true,
					:convert => :to_i },

				{ :name => :critical,
					:required => true,
					:convert => :to_i },

				{ :name => :name }

			]

		@name = @opts[:name] || @name

	end

	def perform_checks

		now = Time.now.to_i

		warning_count = 0
		critical_count = 0

		oldest = 0

		@files.each do
			|file|

			info = RRD.info file

			last_update = info["last_update"]

			age = now - last_update

			if age >= @opts[:critical]
				critical_count += 1
			elsif age >= @opts[:warning]
				warning_count += 1
			end

			oldest = age if age > oldest

		end

		message "#{@files.size} graphs"
		critical "#{critical_count} critical" if critical_count > 0
		warning "#{warning_count} warning" if warning_count > 0
		message "oldest is #{oldest}s"

	end

end
