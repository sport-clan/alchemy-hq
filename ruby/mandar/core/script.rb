require "mandar/tools"

class Mandar::Core::Script

	include Mandar::Tools::Escape

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

	def parse_args()
		require "getoptlong"

		opts = GetoptLong.new(*[

			[ "--mock", "-m", GetoptLong::NO_ARGUMENT ],
			[ "--no-config", "-c", GetoptLong::NO_ARGUMENT ],
			[ "--no-database", "-d", GetoptLong::NO_ARGUMENT ],
			[ "--series", "-s", GetoptLong::NO_ARGUMENT ],
			[ "--profile", "-p", GetoptLong::REQUIRED_ARGUMENT ],

			[ "--quiet", "-0", GetoptLong::NO_ARGUMENT ],
			[ "--normal", "-1", GetoptLong::NO_ARGUMENT ],
			[ "--verbose", "-2", GetoptLong::NO_ARGUMENT ],
			[ "--debug", "-3", GetoptLong::NO_ARGUMENT ],
			[ "--timing", "-4", GetoptLong::NO_ARGUMENT ],
			[ "--trace", "-5", GetoptLong::NO_ARGUMENT ],
			[ "--html", GetoptLong::NO_ARGUMENT ],

			[ "--role", GetoptLong::REQUIRED_ARGUMENT ],
			[ "--staged", GetoptLong::NO_ARGUMENT ],
			[ "--rollback", GetoptLong::NO_ARGUMENT ],
			[ "--force", "-f", GetoptLong::NO_ARGUMENT ],

			[ "--fork", GetoptLong::NO_ARGUMENT ],
			[ "--pid-file", GetoptLong::REQUIRED_ARGUMENT ],
			[ "--log-file", GetoptLong::REQUIRED_ARGUMENT ],
		])

		$no_config = false
		$no_database = false
		$series = false
		$force = false
		$mock = false
		$profile = nil
		$deploy_role = nil
		$deploy_mode = :unstaged

		$console_fork = false
		$console_pid_file = nil
		$console_log_file = nil

		opts.each do |opt, arg|
			case opt

			when "--debug"

				Mandar.logger.level != :notice \
					and Mandar.die "Only one log level option allowed"

				Mandar.logger.level = :debug

			when "--mock"
				$mock = true

			when "--no-config"
				$no_config = true

			when "--no-database"
				$no_database = true

			when "--quiet"

				Mandar.logger.level != :notice \
					and Mandar.die "Only one log level option allowed"

				Mandar.logger.level = :warning

			when "--series"
				$series = true

			when "--trace"

				Mandar.logger.level != :notice \
					and Mandar.die "Only one log level option allowed"

				Mandar.logger.level = :trace

			when "--timing"

				Mandar.logger.level != :notice \
					and Mandar.die "Only one log level option allowed"

				Mandar.logger.level = :timing

			when "--verbose"

				Mandar.logger.level != :notice \
					and Mandar.die "Only one log level option allowed"

				Mandar.logger.level = :detail

			when "--profile"

				$profile == nil \
					or Mandar.die "Only one --profile option allowed"

				$profile = arg

			when "--html"

				Mandar.logger.format == :html \
					and Mandar.die "Only one --html option allowed"

				Mandar.logger.format = :html

			# ---------- deploy

			when "--role"
				$deploy_role and Mandar.die "Only one --role option allowed"
				$deploy_role = arg

			when "--staged"
				$deploy_mode == :unstaged or Mandar.die "Only one --staged and/or --rollback option allowed"
				$deploy_mode = :staged

			when "--rollback"
				$deploy_mode == :unstaged or Mandar.die "Only one --staged and/or --rollback option allowed"
				$deploy_mode = :rollback

			when "--force"
				$force and Mandar.die "Online one --force option allowed"
				$force = true

			# ---------- console

			when "--fork"
				$console_fork and Mandar.die "Only one --fork option allowed"
				$console_fork = true

			when "--pid-file"
				$console_pid_file and Mandar.die "Only one --pid-file option allowed"
				$console_pid_file = arg

			when "--log-file"
				$console_log_file and Mandar.die "Only one --log-file option allowed"
				$console_log_file = arg

			# ----------

			else
				raise "Internal error: unrecognised argument #{opt}"

			end
		end
	end

	def main()
		STDOUT.sync = true
		argv_copy = ARGV.clone
		parse_args
		Mandar.trace "executing #{File.basename $0} #{argv_copy.join " "}"
		begin
			do_command
		rescue => e
			Mandar.error "got error #{e.message}"
			Mandar.detail(([ e.inspect ] + e.backtrace).join("\n"))
		end
	end

	def process_hosts args
		abstract = Mandar::Core::Config.abstract
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

	def do_command
		case ARGV[0]

			when "config"
				Mandar.host = "local"
				hosts = ARGV.size > 1 ? process_hosts(ARGV[1..-1]) : nil
				Mandar::Core::Config.rebuild_abstract
				Mandar::Core::Config.rebuild_concrete hosts

			when "deploy"
				Mandar.host = "local"

				# check args
				$deploy_role or Mandar.die "must specify --role in deploy mode"

				# message about mock
				Mandar.warning "running in mock deployment mode" if $mock

				# begin staged/rollback deploy

				Mandar::Core::Config.stager_start $deploy_mode, $deploy_role, $mock

				# rebuild config

				Mandar::Core::Config.rebuild_abstract

				abstract = Mandar::Core::Config.abstract

				# determine list of hosts to deploy to

				hosts = process_hosts ARGV[1..-1]

				# reduce list of hosts on various criteria

				hosts = hosts.select do |host|
					host_elem = abstract["deploy-host"].find_first("deploy-host[@name='#{host}']")
					case
					when host == "local"
						true
					when ! host_elem
						Mandar.die "No such host #{host}"
					when ! host_elem.attributes["skip"].to_s.empty?
						Mandar.debug "skipping host #{host} because #{host_elem.attributes["skip"]}"
						false
					when host_elem.attributes["no-deploy"] != "yes"
						true
					when $force
						Mandar.warning "deploying to no-deploy host #{host}"
						true
					else
						Mandar.warning "skipping no-deploy host #{host}"
						false
					end
				end

				# rebuild concrete config
				Mandar::Core::Config.rebuild_concrete hosts

				# and deploy
				Mandar::Master.deploy hosts

			when "server-deploy"

				require "hq/deploy"

				HQ::Deploy::Slave.go \
					ARGV[1]

			when "action"
				Mandar.host = "local"
				Mandar::Core::Config.rebuild_abstract
				cdb = Mandar.cdb
				hosts = cdb.view_key("root", "by_type", "host")["rows"].map { |row| row["value"] }
				hosts.each do |host|
					next unless host["action"].is_a?(String) && ! host["action"].empty?
					Mandar::Master::Actions.perform cdb, host
				end

			when "ec2-instances"
				raise "syntax error" unless ARGV.length == 2
				Mandar.host = "local"
				ec2 = Mandar::EC2.connect ARGV[1]
				Mandar::EC2::Reports.instances ec2

			when "ec2-snapshots-summary"
				raise "syntax error" unless ARGV.length == 2
				Mandar.host = "local"
				ec2 = Mandar::EC2.connect ARGV[1]
				Mandar::EC2::Reports.snapshots_summary ec2

			when "console-config"

				Mandar.host = "local"
				Mandar::Core::Config.rebuild_abstract

				Mandar.notice "creating console config"

				mandar = Mandar::Core::Config.mandar
				profile = Mandar::Core::Config.profile
				abstract = Mandar::Core::Config.abstract

				# create console-config.xml
				doc = XML::Document.new
				doc.root = XML::Node.new "console-config"
				doc.root.attributes["database-host"] = profile.attributes["database-host"]
				doc.root.attributes["database-port"] = profile.attributes["database-port"]
				doc.root.attributes["database-name"] = profile.attributes["database-name"]
				doc.root.attributes["database-user"] = profile.attributes["database-user"]
				doc.root.attributes["database-pass"] = profile.attributes["database-pass"]
				doc.root.attributes["deploy-command"] = "#{CONFIG}/#{File.basename $0}"
				doc.root.attributes["deploy-profile"] = $profile
				doc.root.attributes["admin-group"] = mandar.attributes["admin-group"]
				doc.root.attributes["path-prefix"] = ""
				doc.root.attributes["http-port"] = "8080"
				doc.root.attributes["url-prefix"] = "http://localhost:8080"
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
				].each do |name, sort_by|
					elems = abstract[name].to_a
					sort_by = [ sort_by ].flatten
					elems.sort! do |elem_a, elem_b|
						sort_a = sort_by.map { |attr_name| elem_a.attributes[attr_name] }
						sort_b = sort_by.map { |attr_name| elem_a.attributes[attr_name] }
						sort_a <=> sort_b
					end
					elems.each do |elem|
						doc.root << doc.import(elem)
					end
				end

				File.open("#{CONFIG}/etc/console-config.xml", "w") { |f| f.puts(doc.to_s) }

				Mandar.notice "done"

			when "help", nil
				puts HELP

			when "clean"
				Mandar::Master.disconnect_all

			when "unlock"

				locks = Mandar.cdb.get "mandar-locks"
				if locks["deploy"]
					if locks["deploy"]["role"] == $deploy_role
						Mandar.warning "unlocking deployment for role #{locks["deploy"]["role"]}"
						locks["deploy"] = nil
					else
						Mandar.error "not unlocking deployment for role #{locks["deploy"]["role"]}"
					end
				end
				locks["changes"].each do |role, change|
					next if change["state"] == "stage"
					if role == $deploy_role
						Mandar.warning "unlocking changes in state #{change["state"]} for role #{role}"
						change["state"] = "stage"
					else
						Mandar.warning "not unlocking changes in state #{change["state"]} for role #{role}"
					end
				end
				Mandar.cdb.update locks

			when "verify"

				relax_abstract = Mandar::Core::Config.load_relax_ng "#{CONFIG}/etc/abstract.rnc"
				relax_concrete = Mandar::Core::Config.load_relax_ng "#{MANDAR}/etc/concrete.rnc"

				Mandar.host = "local"

				Mandar::Core::Config.rebuild_abstract
				Dir.new("#{WORK}/abstract").each do |dir|
					next if dir[0] == ?.
					Dir.new("#{WORK}/abstract/#{dir}").each do |file|
						next unless file =~ /\.xml$/
						doc = XML::Document.file("#{WORK}/abstract/#{dir}/#{file}")
						doc.validate_relaxng(relax_abstract)
					end
				end
				Mandar.notice "all abstract xml confirmed as valid"

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
				Mandar.notice "all concrete xml confirmed as valid"

			when "console"

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

			when "run"
				Mandar.host = "local"
				hosts = process_hosts([ ARGV[1] ])
				Mandar::Master.run_command hosts, ARGV[2..-1].join(" ")

			when "server-run"
				Mandar::Support::Core.shell ARGV[1]

			when "export"

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
				Mandar.cdb.all_docs["rows"].each do |row|
					updates << {
						"_id" => row["id"],
						"_rev" => row["value"]["rev"],
						"_deleted" => true,
					}
				end
				Mandar.cdb.bulk updates

				# design documents

				Mandar.cdb.create({
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
				Mandar.error "syntax error"

		end
	end
end
