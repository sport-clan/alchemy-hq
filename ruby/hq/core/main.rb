module HQ
module Core
class Main

	require "hq/tools/escape"
	include HQ::Tools::Escape

	attr_accessor :config_dir
	attr_accessor :work_dir
	attr_accessor :deploy_dir
	attr_accessor :remote_command

	def hostname= new_hostname
		@hostname = new_hostname
		@logger.hostname = new_hostname if @logger
	end

	def initialize
		@commands = {}
	end

	def main all_args

		command_args =
			process_args all_args

		begin
			do_command command_args
		rescue SystemExit
			# just exit
		rescue Exception => e
			logger.error "got error #{e.message}"
			logger.detail([ e.inspect, *e.backtrace ].join("\n"))
		ensure
			tidy_up
		end

	end

	def tidy_up

		begin
			@mq_wrapper.stop if @mq_wrapper
		rescue => e
			puts "Error stopping mq_wrapper", e.message, e.backtrace
		end

		begin
			@em_wrapper.stop if @em_wrapper
		rescue => e
			puts "Error stopping em_wrapper", e.message, e.backtrace
		end

	end

	def logger

		return @logger if @logger

		require "hq/tools/logger"

		@logger =
			HQ::Tools::Logger.new

		@logger.hostname =
			hostname

		return @logger

	end

	def engine

		return @engine if @engine

		require "hq/engine/engine"

		@engine =
			HQ::Engine::Engine.new

		@engine.main = self

		return @engine

	end

	def couch

		return @couch if @couch

		require "hq/couchdb/couchdb-server"

		couch_server =
			HQ::CouchDB::Server.new \
				profile["database-host"],
				profile["database-port"]

		couch_server.logger = logger

		couch_server.auth \
			profile["database-user"],
			profile["database-pass"]

		@couch =
			couch_server.database \
				profile["database-name"]

		return @couch

	end

	def em_wrapper

		return @em_wrapper if @em_wrapper

		require "hq/core/event-machine-fibre-wrapper"

		@em_wrapper =
			HQ::Core::EventMachineFibreWrapper.new

		@em_wrapper.start

		return @em_wrapper

	end

	def mq_wrapper

		return @mq_wrapper if @mq_wrapper

		require "hq/mq/mq-wrapper"

		@mq_wrapper =
			HQ::MQ::MqWrapper.new

		@mq_wrapper.em_wrapper = em_wrapper

		@mq_wrapper.host = profile["mq-host"]
		@mq_wrapper.port = profile["mq-port"]
		@mq_wrapper.vhost = profile["mq-vhost"]
		@mq_wrapper.username = profile["mq-user"]
		@mq_wrapper.password = profile["mq-pass"]

		@mq_wrapper.start

		return @mq_wrapper

	end

	def continue
		@em_wrapper.continue if @em_wrapper
	end

	def hostname

		return @hostname if @hostname

		if File.exists? "/etc/hq-hostname"
			@hostname = File.read("/etc/hq-hostname").strip
		else
			require "socket"
			@hostname = Socket.gethostname.split(".")[0]
		end

		return @hostname

	end

	def config

		return @config if @config

		require "xml"

		config_path =
			"#{config_dir}/etc/hq-config.xml"

		if File.exists? config_path

			# load config

			config_doc =
				XML::Document.file \
					config_path,
					:options => XML::Parser::Options::NOBLANKS

			@config =
				config_doc.root

		else

			# default empty config

			config_doc =
				XML::Document.string("<hq-config/>")

			@config =
				config_doc.root

		end

		return @config

	end

	def process_args all_args

		require "getoptlong"

		opts =
			GetoptLong.new(*[

				[ "--mock", GetoptLong::NO_ARGUMENT ],
				[ "--no-config", GetoptLong::NO_ARGUMENT ],
				[ "--no-database", GetoptLong::NO_ARGUMENT ],
				[ "--series", GetoptLong::NO_ARGUMENT ],
				[ "--profile", GetoptLong::REQUIRED_ARGUMENT ],
				[ "--deploy-id", GetoptLong::REQUIRED_ARGUMENT ],

				[ "--log", GetoptLong::REQUIRED_ARGUMENT ],

				[ "--role", GetoptLong::REQUIRED_ARGUMENT ],
				[ "--staged", GetoptLong::NO_ARGUMENT ],
				[ "--rollback", GetoptLong::NO_ARGUMENT ],
				[ "--force", GetoptLong::NO_ARGUMENT ],

				[ "--log-file", GetoptLong::REQUIRED_ARGUMENT ],

				[ "--ssh-identity", GetoptLong::REQUIRED_ARGUMENT ],

			])

		$no_config = false
		$no_database = false
		$series = false
		$force = false
		$mock = false
		$profile = nil
		$deploy_role = nil
		$deploy_mode = :unstaged
		$deploy_id = nil

		got_log = false

		$passthru_args = []

		$ssh_identity = nil

		opts.each do
			|opt, arg|

			case opt

			when "--mock"
				$mock = true
				$passthru_args << [ "--mock" ]

			when "--no-config"
				$no_config = true

			when "--no-database"
				$no_database = true

			when "--series"
				$series = true

			when "--profile"
				$profile = arg

			when "--log"
				logger.add_auto arg
				got_log = true

			when "--role"

				$deploy_role \
					and logger.die "Only one --role option allowed"

				$deploy_role = arg

			when "--deploy-id"

				$deploy_id \
					and logger.die "Only one --deploy-id option allowed"

				$deploy_id = arg

			# mode

			when "--staged"

				$deploy_mode == :unstaged \
					or logger.die "Only one --staged and/or --rollback " +
						"option allowed"

				$deploy_mode = :staged

			when "--rollback"

				$deploy_mode == :unstaged \
					or logger.die "Only one --staged and/or --rollback " +
						"option allowed"

				$deploy_mode = :rollback

			when "--force"

				$force \
					and logger.die "Online one --force option allowed"

				$force = true

			# ssh

			when "--ssh-identity"

				$ssh_identity \
					and logger.die "Only one --ssh-identity option allowed"

				$ssh_identity = arg

			# default

			else
				raise "Internal error: unrecognised argument #{opt}"

			end
		end

		# set defaults

		config_script =
			config.find_first("script")

		config_script ||=
			XML::Node.new "script"

		$profile ||=
			config_script["default-profile"]

		$deploy_role ||=
			config_script["default-role"]

		unless got_log
			logger.add_auto \
				config_script["default-log"] || "detail:ansi"
		end

		return ARGV

	end

	def profile

		return @profile \
			if @profile

		profile =
			config.find_first("profile[@name='#{$profile}']")

		profile \
			or logger.die "No such profile: #{$profile}"

		return @profile = profile

	end

	def register_command name, args = nil, info = nil, &proc

		@commands[name] = {
			info: info,
			args: args,
			info: info,
			proc: proc,
		}

	end

	def do_command args

		if args.size < 1
			logger.die "TODO help"
		end

		command_name =
			args.shift

		command_meta =
			@commands[command_name]

		if ! command_meta
			logger.die "Command not recognised: #{command_name}"
		end

		command =
			command_meta[:proc].call self

		command.go command_name, *args

	end

=begin
	def do_command

		case ARGV[0]

			when "ec2-instances"
				raise "syntax error" unless ARGV.length == 2
				@hostname = "local"
				ec2 = Mandar::EC2.connect ARGV[1]
				Mandar::EC2::Reports.instances ec2

			when "ec2-snapshots-summary"
				raise "syntax error" unless ARGV.length == 2
				@hostname = "local"
				ec2 = Mandar::EC2.connect ARGV[1]
				Mandar::EC2::Reports.snapshots_summary ec2

			when "help", nil
				puts HELP

			when "clean"
				logger.die "TODO"
				Mandar::Master.disconnect_all
				if File.directory? WORK
					logger.notice "removing #{WORK}"
					FileUtils.remove_entry_secure WORK
				end

			when "verify"
				logger.die "TODO"

				relax_abstract = Mandar::Core::Config.load_relax_ng "#{CONFIG}/etc/abstract.rnc"
				relax_concrete = Mandar::Core::Config.load_relax_ng "#{MANDAR}/etc/concrete.rnc"

				@hostname = "local"

				Mandar::Core::Config.rebuild_abstract
				Dir.new("#{WORK}/abstract").each do |dir|
					next if dir[0] == ?.
					Dir.new("#{WORK}/abstract/#{dir}").each do |file|
						next unless file =~ /\.xml$/
						doc = XML::Document.file("#{WORK}/abstract/#{dir}/#{file}")
						doc.validate_relaxng(relax_abstract)
					end
				end
				logger.notice "all abstract xml confirmed as valid"

				Mandar::Core::Config.rebuild_concrete
				Dir.new("#{WORK}/concrete").each do |host|
					next unless host =~ /^[a-z]+$/
					Dir.new("#{WORK}/concrete/#{host}").each do |file|
						next unless file =~ /\.xml$/
						doc = XML::Document.file("#{WORK}/concrete/#{host}/#{file}")
						doc.validate_relaxng(relax_concrete)
					end
					GC.start
				end
				logger.notice "all concrete xml confirmed as valid"

			when "console"

				require "mandar/console"
				Mandar.logger = logger
				Object.const_set "CONFIG", config_dir

				if $console_fork
					pid = fork do
						$stdin.close
						$stdout.reopen $console_log_file, "a"
						$stdout.sync = true
						$stderr.reopen $console_log_file, "a"
						$stderr.sync = true
						File.open($console_pid_file, "w") { |f| f.puts $$ }
						at_exit { File.unlink $console_pid_file }
						Mandar::Console::Server.new.run
					end
				else
					Mandar::Console::Server.new.run
				end

			when "run"
				logger.die "TODO"

				@hostname = "local"

				sep = ARGV.index ""
				sep or raise "Syntax error"

				requested_hosts = ARGV[1...sep]
				cmd_args = ARGV[(sep+1)..-1]

				Mandar::Core::Config.rebuild_abstract

				processed_hosts =
					process_hosts requested_hosts

				filtered_hosts =
					filter_hosts \
						processed_hosts,
						"running on",
						requested_hosts

				Mandar::Master.run_command \
					filtered_hosts,
					cmd_args.join(" ")

			when "export"
				logger.die "TODO"

				raise "syntax error" unless ARGV.length == 2
				zip_name = ARGV[1]

				Mandar::Core::Config.data_ready

				require "zip/zip"

				Zip::ZipOutputStream.open zip_name do |zip|

					# write schema

					zip.put_next_entry "schema.xml"
					zip << File.read("#{WORK}/schema.xml")

					# write data

					Mandar::Core::Config.data_strs.each do |name, doc|
						zip.put_next_entry "data/#{name}.xml"
						zip << doc
					end

				end

			when "import"
				logger.die "TODO"

				raise "syntax error" unless ARGV.length == 2
				zip_name = ARGV[1]

				require "zip/zip"

				# load schema

				schemas_doc = Zip::ZipFile.open zip_name do |zip|
					io = zip.get_input_stream "schema.xml"
					XML::Document.io io,
						:options =>XML::Parser::Options::NOBLANKS
				end
				schemas_elem = schemas_doc.root

				# delete existing

				updates = []
				couchdb.all_docs["rows"].each do |row|
					updates << {
						"_id" => row["id"],
						"_rev" => row["value"]["rev"],
						"_deleted" => true,
					}
				end
				couchdb.bulk updates

				# design documents

				couchdb.create({
					"_id" => "_design/root",
					"language" => "javascript",
					"views" => {
						"by_type" => {
							"map" =>
								"function (doc) {\n" \
								"    if (! doc.transaction) return;\n" \
								"    emit (doc.type, doc);\n" \
								"}\n",
						}
					},
				})

				# add new

				Zip::ZipInputStream.open zip_name do |zip|
					while entry = zip.get_next_entry

						next unless entry.name =~ /^data\/(.+).xml$/
						name = $1

						schema_elem =
							schemas_elem.find_first \
								"schema [ @name = #{xp name} ]"

						updates = []

						doc = XML::Document.string zip.read,
							:options =>XML::Parser::Options::NOBLANKS

						doc.find("/data/*").each do |elem|

							json = Mandar::Core::Config.xml_to_json \
								schemas_elem,
								schema_elem,
								elem

							id_parts =
								schema_elem.find("id/*").to_a.map do |id_elem|
									json[id_elem.attributes["name"]]
								end

							updates << {
								"_id" => "current/#{name}/#{id_parts.join("/")}",
								"transaction" => "current",
								"type" => name,
								"source" => "data",
								"value" => json,
							}
						end

						Mandar.cdb.bulk updates

					end
				end

			else
				logger.error "syntax error"

		end

	end
=end

end
end
end
