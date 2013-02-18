require "hq"

require "hq/tools/escape"

class HQ::Application

	include HQ::Tools::Escape

	attr_accessor :config_dir
	attr_accessor :work_dir
	attr_accessor :deploy_dir
	attr_accessor :remote_command

	attr_accessor :hostname
	attr_accessor :config

	attr_accessor :logger
	attr_accessor :couch

	attr_accessor :deploy_master
	attr_accessor :deploy_slave

	def main

		init_logger

		load_config

		process_args

		begin
			do_command
		rescue => e
			logger.error "got error #{e.message}"
			logger.detail(([ e.inspect ] + e.backtrace).join("\n"))
		end

	end

	def init_logger

		require "hq/tools/logger"

		self.hostname =
			determine_hostname

		self.logger =
			HQ::Tools::Logger.new

		logger.hostname =
			hostname

	end

	def init_deploy_master

		require "hq/deploy/master"

		self.deploy_master =
			HQ::Deploy::Master.new

		init_couch

		deploy_master.config = config
		deploy_master.hostname = hostname
		deploy_master.config_dir = config_dir
		deploy_master.work_dir = work_dir
		deploy_master.deploy_dir = deploy_dir
		deploy_master.remote_command = remote_command

		deploy_master.logger = logger
		deploy_master.couch = couch

	end

	def init_deploy_slave deploy_path

		require "hq/deploy/slave"

		self.deploy_slave =
			HQ::Deploy::Slave.new

		deploy_slave.logger = logger

		deploy_slave.hostname = hostname
		deploy_slave.config_dir = config_dir
		deploy_slave.work_dir = work_dir
		deploy_slave.deploy_path = deploy_path

	end

	def init_couch

		require "hq/couchdb/server"

		couch_server =
			HQ::CouchDB::Server.new \
				profile["database-host"],
				profile["database-port"]

		couch_server.logger =
			logger

		couch_server.auth \
			profile["database-user"],
			profile["database-pass"]

		self.couch =
			couch_server.database \
				profile["database-name"]

	end

	def determine_hostname

		if File.exists? "/etc/hq-hostname"
			return File.read("/etc/hq-hostname").strip
		end

		return Socket.gethostname.split(".")[0]

	end

	HELP = [
		"",
		"Usage: #{File.basename($0)} [GLOBAL-OPTION...] COMMAND [ARG...] [COMMAND-OPTION...]",
		"",
		"Commands:",
		"",
		"    help                Display this message",
		"    config              Rebuild configuration",
		"    clean               Shut down SSH connections and clear generated config",
		"    verify              Validate generated xml (abstract and concrete)",
		"    deploy HOST...      Deploy to specified hosts",
		"",
		"General options:",
		"",
		"    -m, --mock          Log actions but don't do them",
		"    -c, --no-config     Don't rebuild configuration",
		"    -d, --no-database   Don't access CouchDB",
		"    -p, --profile NAME  Specify config profile to use",
		"    -s, --series        Perform deployments in series",
		"",
		"Output options:",
		"",
		"    -0, --quiet         Show errors and warnings",
		"    -1, --normal        Show normal log",
		"    -2, --verbose       Show detailed log",
		"    -3, --debug         Show debug log",
		"    -4, --timing        Show timing log",
		"    -5, --trace         Show trace log",
		"    --html              Generate HTML output",
		"",
		"Deploy command options:",
		"",
		"    --role ROLE         Specify role, required",
		"    --staged USER       Merge staged changes",
		"    --rollback USER     Rollback staged changes",
		"    -f, --force         Ignore no-deploy flag on hosts",
		"",
	].join("\n") + "\n"

	def load_config

		require "xml"

		config_path =
			"#{config_dir}/etc/hq-config.xml"

		if File.exists? config_path

			# load config

			config_doc =
				XML::Document.file \
					config_path,
					:options => XML::Parser::Options::NOBLANKS

			self.config =
				config_doc.root

		else

			# default empty config

			config_doc =
				XML::Document.string("<hq-config/>")

			self.config =
				config_doc.root

		end

	end

	def process_args

		require "getoptlong"

		opts =
			GetoptLong.new(*[

				[ "--mock", "-m", GetoptLong::NO_ARGUMENT ],
				[ "--no-config", "-c", GetoptLong::NO_ARGUMENT ],
				[ "--no-database", "-d", GetoptLong::NO_ARGUMENT ],
				[ "--series", "-s", GetoptLong::NO_ARGUMENT ],
				[ "--profile", "-p", GetoptLong::REQUIRED_ARGUMENT ],

				[ "--log", "-l", GetoptLong::REQUIRED_ARGUMENT ],

				[ "--role", GetoptLong::REQUIRED_ARGUMENT ],
				[ "--staged", GetoptLong::NO_ARGUMENT ],
				[ "--rollback", GetoptLong::NO_ARGUMENT ],
				[ "--force", "-f", GetoptLong::NO_ARGUMENT ],

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

		got_log = false

		$passthru_args = []

		$ssh_identity = nil

		opts.each do |opt, arg|
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

				$deploy_role and logger.die "Only one --role option allowed"

				$deploy_role = arg

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

	def process_hosts args

		abstract =
			deploy_master.abstract

		hosts = []
		for arg in args
			if arg == "all"
				abstract["host"].each do |host_elem|
					hosts << host_elem.attributes["name"]
				end
				hosts << "local"
			elsif arg == "local"
				hosts << "local"
			elsif abstract["host"].find_first("host[@name='#{arg}']")
				hosts <<= arg
			elsif abstract["host"].find_first("host[@class='#{arg}']")
				abstract["host"].find("host[@class='#{arg}']").each do |host_elem|
					hosts <<= host_elem.attributes["name"]
				end
			elsif domain_elem = abstract["domain"].find_first("domain[@short-name='#{arg}']")
				domain_name = domain_elem.attributes["name"]
				abstract["host"].find("host[@domain='#{domain_name}']").each do |host_elem|
					hosts <<= host_elem.attributes["name"]
				end
			else
				raise "Unknown host/group #{arg}"
			end
		end
		return hosts
	end

	def filter_hosts hosts, message, requested_hosts

		abstract =
			deploy_master.abstract

		return hosts.select do |host|

			host_xp =
				esc_xp host

			query =
				"deploy-host [@name = #{host_xp}]"

			host_elem =
				abstract["deploy-host"].find_first query

			case

			when host == "local"

				true

			when ! host_elem

				logger.die "No such host #{host}"

			when ! host_elem.attributes["skip"].to_s.empty?

				message = "skipping host #{host} because " +
					"#{host_elem.attributes["skip"]}"

				if requested_hosts.include? host
					logger.warning message
				else
					logger.debug message
				end

				false

			when host_elem.attributes["no-deploy"] != "yes"

				message = "skipping host #{host} because it is " +
					"set to no-deploy"

				true

			when $force

				logger.warning "#{message} no-deploy host #{host}"

				true

			else

				logger.warning "skipping no-deploy host #{host}"

				false

			end

		end

	end

	def do_command
		case ARGV[0]

			when "config"

				logger.die "FIXME"

				self.hostname = "local"

				hosts = ARGV.size > 1 ? process_hosts(ARGV[1..-1]) : nil

				init_deploy_master

				deploy_master.transform

				deploy_master.write hosts

			when "deploy"

				self.hostname = "local"

				# check args

				$deploy_role \
					or logger.die "must specify --role in deploy mode"

				# message about mock

				logger.warning "running in mock deployment mode" \
					if $mock

				# begin staged/rollback deploy

				init_deploy_master

				deploy_master.stager_start \
					$deploy_mode,
					$deploy_role,
					$mock \
				do

					logger.time "transform", :detail do

						# rebuild config

						deploy_master.transform

						# determine list of hosts to deploy to

						requested_hosts = ARGV[1..-1]

						hosts = process_hosts requested_hosts

						# reduce list of hosts on various criteria

						hosts =
							filter_hosts \
								hosts,
								"deploying to",
								requested_hosts

						# output processed config

						deploy_master.write hosts

					end

					logger.time "deploy", :detail do

						# and deploy

						deploy_master.deploy hosts

					end

				end

			when "server-deploy"

				require "hq/deploy"

				# create /alchemy-hq link

				# TODO does this belong here?

				# TODO do this with ruby, not bash

				system \
					"test -h /alchemy-hq " +
					"|| ln -s #{deploy_dir}/alchemy-hq /alchemy-hq"

				# set hostname

				self.hostname = ARGV[1]

				logger.hostname = hostname

				File.open "/etc/hq-hostname", "w" do |f|
					f.puts ARGV[1]
				end

				# and perform the requested deployment

				init_deploy_slave ARGV[2]

				deploy_slave.go

=begin
			when "ec2-instances"
				raise "syntax error" unless ARGV.length == 2
				hostname = "local"
				ec2 = Mandar::EC2.connect ARGV[1]
				Mandar::EC2::Reports.instances ec2

			when "ec2-snapshots-summary"
				raise "syntax error" unless ARGV.length == 2
				hostname = "local"
				ec2 = Mandar::EC2.connect ARGV[1]
				Mandar::EC2::Reports.snapshots_summary ec2
=end

			when "console-config"

				logger.die "TODO"

=begin
				self.hostname = "local"
				Mandar::Core::Config.rebuild_abstract

				logger.notice "creating console config"

				mandar = Mandar::Core::Config.mandar
				profile = Mandar::Core::Config.profile
				abstract = Mandar::Core::Config.abstract

				# create console-config.xml

				doc = XML::Document.new

				doc.root = XML::Node.new "console-config"

				doc.root["database-host"] = profile["database-host"]
				doc.root["database-port"] = profile["database-port"]
				doc.root["database-name"] = profile["database-name"]
				doc.root["database-user"] = profile["database-user"]
				doc.root["database-pass"] = profile["database-pass"]
				doc.root["deploy-command"] = "#{CONFIG}/.stubs/#{File.basename $0}"
				doc.root["deploy-profile"] = $profile
				doc.root["admin-group"] = mandar["admin-group"]
				doc.root["path-prefix"] = ""
				doc.root["http-port"] = "8080"
				doc.root["url-prefix"] = "http://localhost:8080"

				[
					[ "grapher-config", [ ] ],
					[ "grapher-graph", "name" ],
					[ "grapher-graph-template", "name" ],
					[ "grapher-scale", "name" ],
					[ "role", "name" ],
					[ "role-member", [ "role", "member" ] ],
					[ "schema", "name" ],
					[ "schema-option", "name" ],
					[ "permission", [ "type", "subject" ] ],
				].each do
					|name, sort_by|

					elems = abstract[name].to_a

					sort_by = [ sort_by ].flatten

					elems.sort! do |elem_a, elem_b|

						sort_a = sort_by.map {
							|attr_name|
							elem_a.attributes[attr_name]
						}

						sort_b = sort_by.map {
							|attr_name|
							elem_a.attributes[attr_name]
						}

						sort_a <=> sort_b

					end

					elems.each do |elem|
						doc.root << doc.import(elem)
					end

				end

				File.open "#{CONFIG}/etc/console-config.xml", "w" do
					|file|
					file.puts doc.to_s
				end

				logger.notice "done"
=end

			when "help", nil
				puts HELP

			when "clean"
				logger.die "TODO"
=begin
				Mandar::Master.disconnect_all
				if File.directory? WORK
					logger.notice "removing #{WORK}"
					FileUtils.remove_entry_secure WORK
				end
=end

			when "unlock"

				init_couch

				locks =
					couch.get "mandar-locks"

				if locks["deploy"]

					if locks["deploy"]["role"] == $deploy_role

						logger.warning "unlocking deployment for role " +
							"#{locks["deploy"]["role"]}"

						locks["deploy"] = nil

					else

						logger.error "not unlocking deployment for role " +
							"#{locks["deploy"]["role"]}"

					end

				end

				locks["changes"].each do
					|role, change|

					next if change["state"] == "stage"

					if role == $deploy_role

						logger.warning "unlocking changes in state " +
							"#{change["state"]} for role #{role}"

						change["state"] = "stage"

					else

						logger.warning "not unlocking changes in state " +
							"#{change["state"]} for role #{role}"

					end

				end

				couch.update locks

			when "verify"
				logger.die "TODO"

=begin
				relax_abstract = Mandar::Core::Config.load_relax_ng "#{CONFIG}/etc/abstract.rnc"
				relax_concrete = Mandar::Core::Config.load_relax_ng "#{MANDAR}/etc/concrete.rnc"

				self.hostname = "local"

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
=end

			when "console"
				logger.die "TODO"

=begin
				require "mandar/console"

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
=end

			when "run"
				logger.die "TODO"

=begin
				self.hostname = "local"

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
=end

			when "export"
				logger.die "TODO"

=begin
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
=end

			when "import"
				logger.die "TODO"

=begin
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
=end

			else
				logger.error "syntax error"

		end

	end

end
