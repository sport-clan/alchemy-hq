require "hq/tools/logger"

module Mandar

	def self.logger
		return @logger ||= HQ::Tools::Logger.new
	end

	def self.message text, level, *content
		logger.message text, level, *content
	end

	def self.message_partial text, level, *content
		logger.message_partial text, level, options
	end

	def self.message_complete text, level, *content
		logger.message_complete text, level, options
	end

	def self.trace text, *contents
		logger.message text, :trace, *contents
	end

	def self.timing text, *contents
		logger.message text, :timing, *contents
	end

	def self.debug text, *contents
		logger.message text, :debug, *contents
	end

	def self.detail text, *contents
		logger.message text, :detail, *contents
	end

	def self.notice text, *contents
		logger.message text, :notice, *contents
	end

	def self.warning text, *contents
		logger.message text, :warning, *contents
	end

	def self.error text, *contents
		logger.message text, :error, *contents
	end

	def self.time text, level = :timing

		time_start =
			Time.now

		begin

			yield

		ensure

			time_end =
				Time.now

			timing_ms =
				((time_end - time_start) * 1000).to_i

			timing_str =
				case timing_ms
					when (0...1000)
						"%dms" % [ timing_ms ]
					when (1000...10000)
						"%.2fs" % [ timing_ms.to_f / 1000 ]
					when (10000...100000)
						"%.1fs" % [ timing_ms.to_f / 1000 ]
					else
						"%ds" % [ timing_ms / 1000 ]
				end

			message \
				"#{text} took #{timing_str}",
				level

		end

	end

	def self.die text, status = 1
		error text
		exit status
	end

	def self.host= hostname
		@hostname = hostname
	end

	def self.host()

		# cache hostname
		return @hostname if @hostname

		# read it from /etc/hq-hostname
		if File.exists?("/etc/hq-hostname")
			return @hostname = File.read("/etc/hq-hostname").strip
		end

		# default to reported hostname
		return Socket.gethostname.split(".")[0]
	end

	def self.cdb()
		return @cdb if @cdb
		profile = Mandar::Core::Config.profile
		db_host = profile.attributes["database-host"]
		db_port = profile.attributes["database-port"]
		db_name = profile.attributes["database-name"]
		db_user = profile.attributes["database-user"]
		db_pass = profile.attributes["database-pass"]
		@couch_server = Mandar::CouchDB::Server.new(db_host, db_port)
		@couch_server.auth db_user, db_pass
		@cdb = @couch_server.database(db_name)
		return @cdb
	end

	def self.to_bool(arg, default = false)
		case arg
		when nil; default
		when "yes"; true
		when "no"; false
		else raise "Can't convert #{arg.class} (#{arg.to_s}) to boolean"
		end
	end

	def self.deploy_dir=(deploy_dir)
		@deploy_dir = deploy_dir
	end

	def self.deploy_dir()
		@deploy_dir or raise "No deploy_dir specified"
		return @deploy_dir
	end

	def self.remote_command= remote_command
		@remote_command = remote_command
	end

	def self.remote_command
		@remote_command or raise "No remote_command specified"
		return @remote_command
	end

	# escape a string or strings for use as shell arguments
	def self.shell_quote(str)

		# support passing an array of strings by calling recursively
		return str.map { |a| shell_quote a }.join(" ") if str.is_a?(Array)

		# simple strings require no encoding
		return str if str =~ /^[-a-zA-Z0-9_\/:.=@]+$/

		# single quotes for anything with no single quotes
		return "'" + str.gsub("'", "'\\\\''") + "'" unless str =~ /'/

		# double quotes with escapes for everything else
		return "\"" + str.gsub("\\", "\\\\\\\\").gsub("\"", "\\\\\"").gsub("`", "\\\\`").gsub("$", "\\\\$") + "\""
	end

end
