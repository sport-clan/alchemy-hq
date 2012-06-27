module Mandar

	def self.logger
		return @logger ||= Mandar::Tools::Logger.new
	end

	def self.message text, level, options = {}
		logger.message text, level, options
	end

	def self.trace text, options = {}
		logger.message text, :trace, options
	end

	def self.timing text, options = {}
		logger.message text, :timing, options
	end

	def self.debug text, options = {}
		logger.message text, :debug, options
	end

	def self.detail text, options = {}
		logger.message text, :detail, options
	end

	def self.notice text, options = {}
		logger.message text, :notice, options
	end

	def self.warning text, options = {}
		logger.message text, :warning, options
	end

	def self.error text, options = {}
		logger.message text, :error, options
	end

	def self.time text
		time_start = Time.now
		begin
			yield
		ensure
			time_end = Time.now
			timing_ms = ((time_end - time_start) * 1000).to_i
			Mandar.timing "#{text} took #{timing_ms}ms"
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

		# read it from /etc/mandar-hostname
		if File.exists?("/etc/mandar-hostname")
			return @hostname = File.read("/etc/mandar-hostname").strip
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

	def self.uname()
		return @uname ||= `uname`
	end

	def self.cygwin?()
		return uname =~ /^CYGWIN/
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
