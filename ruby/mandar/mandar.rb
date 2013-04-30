require "hq/logger"

module Mandar

	# logger stuff

	def self.logger= logger
		@logger = logger
	end

	def self.logger
		@logger
	end

	def self.message *args
		logger.message *args
	end

	def self.message_partial *args
		logger.message_partial *args
	end

	def self.message_complete *args
		logger.message_complete *args
	end

	def self.trace *args
		logger.trace *args
	end

	def self.timing *args
		logger.timing *args
	end

	def self.debug *args
		logger.debug *args
	end

	def self.detail *args
		logger.detail *args
	end

	def self.notice *args
		logger.notice *args
	end

	def self.warning *args
		logger.warning *args
	end

	def self.error *args
		logger.error *args
	end

	def self.time *args, &proc
		logger.time *args, &proc
	end

	def self.die *args
		logger.die *args
	end

	# hostname

	def self.host= host
		@host = host
	end

	def self.host
		@host
	end

=begin
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
=end

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
