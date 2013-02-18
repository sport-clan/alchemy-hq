require "hq/deploy"

require "hq/tools/escape"

class HQ::Deploy::Master

	attr_accessor :config
	attr_accessor :hostname
	attr_accessor :config_dir
	attr_accessor :work_dir
	attr_accessor :deploy_dir
	attr_accessor :remote_command

	attr_accessor :couch
	attr_accessor :logger

	attr_accessor :abstract_engine
	attr_accessor :xquery_client

	include HQ::Tools::Escape

	def initialize
		require "tempfile"
	end

	def write host_names

		init_abstract_engine

		abstract_results =
			abstract_engine.results

		# write concrete config

		logger.notice "writing deploy config"

		logger.time "writing deploy config" do

			FileUtils.remove_entry_secure "#{work_dir}/deploy" \
				if File.directory? "#{work_dir}/deploy"

			FileUtils.mkdir "#{work_dir}/deploy"
			FileUtils.mkdir "#{work_dir}/deploy/host"
			FileUtils.mkdir "#{work_dir}/deploy/class"

			# write out deploy docs

			class_names = []

			host_names.each do |host_name|

				FileUtils.mkdir "#{work_dir}/deploy/host/#{host_name}"

				deploy_host_elem =
					abstract_results["deploy-host"][:doc] \
						.find_first "deploy-host [@name = #{esc_xp host_name}]"

				deploy_host_elem \
					or raise "No deploy-host found for #{host_name}"

				host_class =
					deploy_host_elem.attributes["class"]

				if host_class
					class_names << host_class \
						unless class_names.include? host_class
				end

				deploy_doc =
					XML::Document.new

				deploy_doc.root =
					XML::Node.new "deploy"

				deploy_doc.root.attributes["host"] =
					host_name

				deploy_host_elem \
					.find("file") \
					.each do |file_elem|

						deploy_doc.root << \
							deploy_doc.import(file_elem)

					end

				deploy_doc.save \
					"#{work_dir}/deploy/host/#{host_name}/deploy.xml"

			end

			# create output documents for each host

			host_docs = {}

			host_names.each do |host_name|
				doc = XML::Document.new
				doc.root = XML::Node.new "tasks"
				host_docs[host_name] = doc
			end

			class_docs = {}

			class_names.each do |class_name|
				doc = XML::Document.new
				doc.root = XML::Node.new "tasks"
				class_docs[class_name] = doc
			end

			# sort tasks into appropriate hosts and classes

			[ "task", "sub-task" ].each do |type|

				next unless abstract_results[type]

				abstract_results[type][:doc] \
						.find("/*/#{type}") \
						.each do |task_elem|

					host_name =
						task_elem.attributes["host"]

					class_name =
						task_elem.attributes["class"]

					case
						when host_name
							doc = host_docs[host_name]
						when class_name
							doc = class_docs[class_name]
						else
							raise "<#{type} name=\"" +
								task_elem.attributes["name"] +
								"\"> has no host or class"
					end

					next unless doc

					doc.root << doc.import(task_elem)

				end

			end

			# write out tasks

			host_docs.each do |host_name, host_doc|

				host_doc.save \
					"#{work_dir}/deploy/host/#{host_name}/tasks.xml"

			end

			class_docs.each do |class_name, class_doc|

				FileUtils.mkdir \
					"#{work_dir}/deploy/class/#{class_name}"

				class_doc.save \
					"#{work_dir}/deploy/class/#{class_name}/tasks.xml"

			end

		end

	end

	def stager_start \
			deploy_mode,
			deploy_role,
			deploy_mock,
			&proc

		[ :unstaged, :staged, :rollback ].include? deploy_mode \
			or raise "Invalid mode: #{deploy_mode}"

		mode_text = {
			:unstaged => "unstaged deploy",
			:staged => "staged deploy",
			:rollback => "rollback"
		} [deploy_mode]

		# control differences between staged deploy and rollback

		# attempt to work around segfaults
		change_pending_state = nil

		unless deploy_mode == :unstaged
			change_pending_state = {
				:staged => "deploy",
				:rollback => "rollback"
			} [deploy_mode]
			change_done_state = {
				:staged => "done",
				:rollback => "stage"
			} [deploy_mode]
			change_start_timestamp = {
				:staged => "deploy-timestamp",
				:rollback => "rollback-timestamp",
			} [deploy_mode]
			change_done_timestamp = {
				:staged => "done-timestamp",
				:rollback => "rollback-done-timestamp",
			} [deploy_mode]
		end

		# load locks

		locks = couch.get "mandar-locks"
		locks or raise "Internal error"

		# check for concurrent deployment

		locks["deploy"] \
			and logger.die "another deployment is in progress for role " +
				"#{locks["deploy"]["role"]}"

		# check for concurrent changes

		locks["changes"].each do |role, change|

			next if change["state"] == "stage"
			next if change["role"] == deploy_role && deploy_mode != :unstaged

			logger.die "another deployment has uncommited changes for role " +
				"#{role}"

		end

		# find our changes

		if deploy_mode != :unstaged

			change = locks["changes"][deploy_role]
			change or logger.die "no staged changes for #{deploy_role}"

			[ "stage", "done" ].include? change["state"] \
				or logger.die "pending changes in invalid state " +
					"#{change["state"]} for role #{deploy_role}"

		end

		# display confirmation

		logger.notice "beginning #{mode_text} for role #{deploy_role}"

		# allocate seq

		lock_seq = locks["next-seq"]
		locks["next-seq"] += 1

		# create lock

		locks["deploy"] = {
			"role" => deploy_role,
			"host" => Socket.gethostname,
			"timestamp" => Time.now.to_i,
			"type" => deploy_mode.to_s,
			"seq" => lock_seq,
			"mock" => deploy_mock,
		}

		# update change state

		unless deploy_mock
			if deploy_mode != :unstaged
				change["state"] = change_pending_state
				change[change_start_timestamp] = Time.now.to_i
			end
		end

		begin

			# save locks

			couch.update locks

			# yield to caller

			proc.call

		ensure

			# load locks

			locks = couch.get "mandar-locks"
			locks or raise "Internal error"

			# check seq

			locks["deploy"]["seq"] == lock_seq \
				or logger.die "Lock sequence number changed"

			# clear lock

			locks["deploy"] = nil

			unless deploy_mock
				if deploy_mode != :unstaged

					# find our changes

					change =
						locks["changes"][deploy_role]

					change \
						or raise "Internal error"

					change["state"] == change_pending_state \
						or raise "Internal error"

					# update change state

					change["state"] = change_done_state
					change[change_done_timestamp] = Time.now.to_i

				end
			end

			# save locks

			couch.update locks

			# display confirmation

			logger.notice "finished #{mode_text} for role #{deploy_role}"

		end

	end

	def transform

		return if warn_no_config

		# ensure work dir exists

		if File.exist? "#{work_dir}/error-flag"
			logger.warning "removing work directory due to previous error"
			FileUtils.rm_rf work_dir
		end

		FileUtils.mkdir_p work_dir

		# ensure schema doc exists and remember it

		schema_file = "#{work_dir}/schema.xml"

		unless File.exists? schema_file

			logger.trace "writing schema.xml (empty)"

			File.open schema_file, "w" do |f|
				f.print "<schemas/>"
			end

		end

		old_schema_data = File.read(schema_file)

		init_xquery_client
		init_abstract_engine

		while true

			data_ready

			# process abstract config

			abstract_engine.rebuild @data_docs

			# write new schema file

			logger.trace "writing schema.xml"
			Tempfile.open("alchemy-hq-schemas-xml-") do |f|
				doc = XML::Document.new
				doc.root = XML::Node.new "schemas"

				%W[ schema schema-option abstract-rule ].each do |elem_name|
					schema_result = abstract_engine.results[elem_name]
					if schema_result
						schema_result[:doc].root.find(elem_name).each do |schema_elem|
							doc.root << doc.import(schema_elem)
						end
					end
				end
				doc_str = doc.to_s
				f.puts doc_str
				f.flush
				FileUtils.move f.path, schema_file
			end
			@schemas_elem = nil

			# if schema file hasn't changed then we're done, otherwise start again

			new_schema_data = File.read(schema_file)
			break if new_schema_data == old_schema_data
			old_schema_data = new_schema_data
			logger.notice "restart due to schema changes"

		end

	end

	def warn_no_config
		return false unless $no_config
		return true if @warned_no_config
		logger.warning "not rebuilding configuration due to --no-config option"
		@warned_no_config = true
		return true
	end

	def data_ready
		if $no_database
			logger.warning "not dumping data due to --no-database option"
			data_load
		else
			data_dump
		end
	end

	def data_dump

		logger.notice "dumping data"

		require "xml"

		logger.time "dumping data" do

			@data_docs = {}
			@data_strs = {}

			FileUtils.remove_entry_secure "#{work_dir}/data" \
				if File.directory? "#{work_dir}/data"

			FileUtils.mkdir_p "#{work_dir}/data", :mode => 0700

			rows = couch.view("root", "by_type")["rows"]
			values_by_type = Hash.new

			legacy = false

			rows.each do |row|

				if legacy

					type = row["value"]["mandar_type"]
					value = row["value"]

				else

					type = row["value"]["type"]
					value = row["value"]["value"]

					row["id"] =~ /^current\/(.+)$/
					value["_id"] = $1

				end

				values_by_type[type] ||= Hash.new
				values_by_type[type][value["_id"]] = value

			end

			change =
				staged_change

			schemas_elem.find("schema").each do |schema_elem|
				schema_name = schema_elem.attributes["name"]

				values = values_by_type[schema_name] || Hash.new

				data_doc = XML::Document.new
				data_doc.root = XML::Node.new "data"

				if change
					change["items"].each do |key, item|
						case item["action"]
						when "create", "update"
							next unless key =~ /^#{Regexp.quote schema_name}\//
							values[key] = item["record"]
						when "delete"
							values.delete key
						else
							raise "Error"
						end
					end
				end

				sorted_values = values.values.sort { |a,b| a["_id"] <=> b["_id"] }
				sorted_values.each do |value|
					data_doc.root << js_to_xml(schemas_elem, schema_elem, value)
				end

				data_str = data_doc.to_s

				File.open "#{work_dir}/data/#{schema_name}.xml", "w" do |f|
					f.print data_str
				end

				@data_docs[schema_name] = data_doc
				@data_strs[schema_name] = data_str
			end

		end

	end

	def data_load

		logger.notice "loading data"

		require "xml"

		logger.time "loading data" do

			@data_docs = {}
			@data_strs = {}

			schemas_elem.find("schema").each do
				|schema_elem|

				schema_name =
					schema_elem.attributes["name"]

				data_path =
					"#{work_dir}/data/#{schema_name}.xml"

				if File.exist? data_path

					data_doc =
						XML::Document.file \
							data_path,
							:options => XML::Parser::Options::NOBLANKS

					data_str =
						data_doc.to_s

				else

					data_doc =
						XML::Document.string \
							"<data/>",
							:options => XML::Parser::Options::NOBLANKS

				end

				@data_docs[schema_name] = data_doc
				@data_strs[schema_name] = data_str

			end

		end

	end

	def staged_change

		return nil \
			unless $deploy_mode == :staged

		locks =
			couch.get "mandar-locks"

		return nil \
			unless locks

		change =
			locks["changes"][$deploy_role]

		return nil \
			unless change

		return change

	end

	def schemas_elem

		return @schemas_elem \
			if @schemas_elem

		schemas_doc =
			XML::Document.file \
				"#{work_dir}/schema.xml",
				:options => XML::Parser::Options::NOBLANKS

		@schemas_elem =
			schemas_doc.root

		return @schemas_elem

	end

	def field_to_xml schemas_elem, fields_elem, value, elem

		value = {} unless value.is_a? Hash
		fields_elem.find("* [name() != 'option']").each do |field_elem|
			field_name = field_elem.attributes["name"]
			case field_elem.name
			when "text", "int", "ts-update", "enum"
				elem.attributes[field_name] = value[field_name].to_s
			when "bigtext"
				prop = XML::Node.new field_name
				prop << value[field_name]
				elem << prop
			when "bool"
				elem.attributes[field_name] = "yes" if value[field_name]

			when "list"
				items = value[field_name]
				if items.is_a? Array
					items.each do |item|
						prop = XML::Node.new field_name
						field_to_xml schemas_elem, field_elem, item, prop
						elem << prop
					end
				end

			when "struct"
				prop = XML::Node.new field_name
				field_to_xml schemas_elem, field_elem, value[field_name], prop
				elem << prop if prop.attributes.length + prop.children.size > 0
			when "xml"
				prop = XML::Node.new field_name
				temp_doc = XML::Document.string "<xml>#{value[field_name]}</xml>", :options =>XML::Parser::Options::NOBLANKS
				temp_doc.root.each { |temp_elem| prop << temp_elem.copy(true) }
				elem << prop
			else
				raise "unexpected element #{field_elem.name} found in field "
					"list for schema #{schema_elem.attributes["name"]}"
			end
		end
		if value["content"].is_a? Array
			value["content"].each do |item|
				item_type = item["type"]
				item_value = item["value"]
				option_elem = fields_elem.find_first("option [@name = '#{item_type}']")
				next unless option_elem
				option_ref = option_elem.attributes["ref"]
				schema_option_elem = schemas_elem.find_first("schema-option [@name = '#{option_ref}']")
				next unless schema_option_elem
				schema_option_props_elem = schema_option_elem.find_first("props")
				prop = XML::Node.new item_type
				field_to_xml schemas_elem, schema_option_props_elem, item_value, prop
				elem << prop
			end
		end
	end

	def field_to_json schemas_elem, schema_elem, fields_elem, elem, value

		fields_elem.find("* [name() != 'option']").each do |field_elem|

			field_name = field_elem.attributes["name"]

			case field_elem.name

				when "text"

					value[field_name] = elem.attributes[field_name]

				when "int", "ts-update"

					temp = elem.attributes[field_name]

					value[field_name] = temp.empty? ? nil : temp.to_i

				when "list"

					value[field_name] = []

					elem.find("* [ name () = #{xp field_name} ]") \
						.each do |child_elem|

						prop = {}

						field_to_json \
							schemas_elem,
							schema_elem,
							field_elem,
							child_elem,
							prop

						value[field_name] << prop
					end

				when "struct"

					prop = {}

					child_elem =
						elem.find_first \
							"* [ name () = #{xp field_name} ]"

					if child_elem
						field_to_json \
							schemas_elem,
							schema_elem,
							field_elem,
							child_elem,
							prop
					end

					value[field_name] = prop unless prop.empty?

				when "xml"

					value[field_name] = ""

					elem.find("* [ name () = #{xp field_name} ] / *") \
						.each do |prop|

						value[field_name] += prop.to_s
					end

				when "bool"

					value[field_name] = \
						elem.attributes[field_name] == "yes"

				when "bigtext"

					value[field_name] =
						elem.find_first("* [ name () = #{xp field_name} ]") \
							.content

				else

					raise "unexpected element #{field_elem.name} found in " \
						"field list for schema " \
						"#{schema_elem.attributes["name"]}"

			end
		end

		content = []

		elem.find("*").each do |child_elem|

			option_elem =
				fields_elem.find_first \
					"option [ @name = #{xp child_elem.name} ]"

			next unless option_elem

			option_ref =
				option_elem.attributes["ref"]

			schema_option_elem =
				schemas_elem.find_first \
					"schema-option [@name = '#{option_ref}']"

			raise "Error" \
				unless schema_option_elem

			schema_option_props_elem =
				schema_option_elem.find_first "props"

			prop = {}

			field_to_json \
				schemas_elem,
				schema_elem,
				schema_option_props_elem,
				child_elem,
				prop

			content << {
				"type" => child_elem.name,
				"value" => prop,
			}

		end

		value["content"] = content \
			unless content.empty?

	end

	def js_to_xml schemas_elem, schema_elem, value

		elem =
			XML::Node.new schema_elem.attributes["name"]

		field_to_xml \
			schemas_elem,
			schema_elem.find_first("id"),
			value,
			elem

		field_to_xml \
			schemas_elem,
			schema_elem.find_first("fields"),
			value,
			elem

		return elem

	end

	def xml_to_json schemas_elem, schema_elem, elem

		value = {}

		field_to_json \
			schemas_elem,
			schema_elem,
			schema_elem.find_first("id"),
			elem,
			value

		field_to_json \
			schemas_elem,
			schema_elem,
			schema_elem.find_first("fields"),
			elem,
			value

		return value
	end

	def abstract

		return @abstract if @abstract

		abstract = {}

		abstract_engine.results.each do
			|result_name, result|

			abstract[result_name] =
				result[:doc].root
		end

		return @abstract = abstract

	end

	def init_xquery_client

		return if @xquery_client

		require "hq/xquery/client"

		logger.debug "starting xquery server"

		spec =
			Gem::Specification.find_by_name "alchemy-hq"

		xquery_server =
			"#{spec.gem_dir}/c++/xquery-server"

		@xquery_client =
			HQ::XQuery.start xquery_server

	end

	def init_abstract_engine

		return if abstract_engine

		require "hq/deploy/abstract-engine"

		@abstract_engine =
			HQ::Deploy::AbstractEngine.new

		abstract_engine.logger = logger
		abstract_engine.xquery_client = xquery_client

		abstract_engine.config_dir = config_dir
		abstract_engine.work_dir = work_dir

	end


	def connect host_name

		host_elem =
			abstract["deploy-host"] \
				.find_first("deploy-host [@name = '#{host_name}']")

		host_elem \
			or raise "No such host: #{host_name}"

		host_hostname =
			host_elem.attributes["hostname"]

		host_hostname \
			or raise "No hostname for host #{host_name}"

		host_ip =
			host_elem.attributes["ip"]

		host_ip \
			or raise "No IP address for host #{host_name}"

		host_ssh_host_key =
			host_elem.attributes["ssh-host-key"]

		host_ssh_host_key \
			or raise "No host key for host #{host_name}"

		host_ssh_key_name =
			host_elem.attributes["ssh-key-name"]

		host_ssh_key_name \
			or raise "No key name for host #{host_name}"

		FileUtils.mkdir_p "#{work_dir}/ssh"
		run_path = "#{work_dir}/ssh/#{host_name}"
		socket_path = "#{run_path}.sock"
		pid_path = "#{run_path}.pid"

		# setup ssh host keys

		system "ssh-keygen -R #{host_hostname} 2>/dev/null"
		system "ssh-keygen -R #{host_ip} 2>/dev/null"
		FileUtils.mkdir_p "#{ENV["HOME"]}/.ssh"
		File.open("#{ENV["HOME"]}/.ssh/known_hosts", "a") do |f|
			f.print "#{host_hostname} #{host_ssh_host_key}\n"
			f.print "#{host_ip} #{host_ssh_host_key}\n"
		end

		ssh_key_elem =
			abstract["mandar-ssh-key"] \
				.find_first("mandar-ssh-key [@name = '#{host_ssh_key_name}']")

		ssh_key =
			ssh_key_elem.find_first("private").content

		unless File.exists? socket_path

			logger.notice "connecting to #{host_name}"

			# write ssh key file

			Tempfile.open "mandar-ssh-key-" do |ssh_key_file|

				ssh_key_file.puts ssh_key
				ssh_key_file.flush

				identity_path =
					$ssh_identity || ssh_key_file.path

				# and execute ssh process

				ssh_args = %W[
					#{HQ::DIR}/etc/ssh-wrapper
					#{run_path}
					ssh -MNqa
					root@#{host_hostname}
					-S #{socket_path}
					-i #{identity_path}
					-o ServerAliveInterval=10
					-o ServerAliveCountMax=3
					-o ConnectTimeout=10
					-o BatchMode=yes
				]

				ssh_cmd = "#{esc_shell ssh_args} </dev/null"

				logger.debug "executing #{ssh_cmd}"

				system ssh_cmd \
					or raise "Error #{$?.exitstatus} executing #{ssh_cmd}"

			end
		end
	end

	def disconnect_all
		if File.directory? "#{work_dir}/ssh"
			Dir.new("#{work_dir}/ssh").each do |filename|
				next unless filename =~ /^(.+)\.pid$/
				host = $1
				logger.notice "disconnecting from #{host}"
				pid = File.read("#{work_dir}/ssh/#{host}.pid").to_i
				Process.kill 15, pid
			end
		end
	end

	def fix_perms

		logger.debug "fixing permissions"

		logger.time "fixing permissions" do

			# everything should only be owner writable but world readable

			system esc_shell [
				"chmod",
				"--recursive",
				"u=rwX,og=rX",
				config_dir,
			] or raise "Error"

			# with the exception of .work which is only owner readable

			system esc_shell [
				"chmod",
				"--recursive",
				"u=rwX,og=",
				"#{config_dir}/.work",
			]

		end

		logger.debug "copying alchemy-hq"

		logger.time "copying alchemy-hq" do

			ahq_spec =
				Gem::Specification.find_by_name "alchemy-hq"

			rsync_args = [

				"rsync",

				"--times",
				"--copy-links",
				"--delete",
				"--executability",
				"--perms",
				"--recursive",

				"#{ahq_spec.gem_dir}/",
				"#{config_dir}/alchemy-hq/",

			]

			rsync_cmd =
				esc_shell rsync_args

			logger.debug "executing #{rsync_cmd}"

			system rsync_cmd \
				or raise "Error #{$?.exitstatus} executing #{rsync_cmd}"

		end

	end

	def send_to host_name

		connect host_name

		message =
			"sending to #{host_name}"

		logger.debug message

		logger.time message do

			host_elem =
				abstract["deploy-host"] \
					.find_first("deploy-host [@name = '#{host_name}']")

			host_elem \
				or raise "No such host #{host_name}"

			host_hostname =
				host_elem.attributes["hostname"]

			host_hostname \
				or raise "No hostname for host #{host_name}"

			rsh_args = [
				"ssh",
				"-S", "#{work_dir}/ssh/#{host_name}.sock",
				"-o", "BatchMode=yes",
				"-o", "ConnectTimeout=10",
			]

			rsh_cmd =
				esc_shell rsh_args

			rsync_args = [

				"rsync",

				"--times",
				"--copy-links",
				"--delete",
				"--executability",
				"--perms",
				"--recursive",
				"--rsh=#{rsh_cmd}",
				"--timeout=30",

			]

			host_elem.find("include").each do |include_elem|

				include_name =
					include_elem.attributes["name"]

				rsync_args += [
					"--include=/.work/deploy/#{include_name}",
				]

			end

			rsync_args += [

				"--exclude=/.work/deploy/*/*",
				"--include=/.work/deploy/*",
				"--include=/.work/deploy",
				"--exclude=/.work/*",
				"--include=/.work",

				"--include=/Gemfile",
				"--include=/Gemfile.lock",
				"--include=/zattikka-hq.gemspec",
				"--include=/vendor",

				"--include=/alchemy-hq",
				"--include=/alchemy-hq/alchemy-hq.gemspec",
				"--include=/alchemy-hq/bin",
				"--include=/alchemy-hq/etc",
				"--exclude=/alchemy-hq/etc/build.properties",
				"--include=/alchemy-hq/ruby",
				"--exclude=/alchemy-hq/*",

				"--include=/bin",
				"--include=/ruby",
				"--include=/scripts",

				"--include=/#{File.basename $0}",

				"--exclude=/*",

				"--exclude=.*",

				"#{config_dir}/",
				"root@#{host_hostname}:/#{deploy_dir}/",

			]

			rsync_cmd =
				"#{esc_shell rsync_args} </dev/null"

			logger.debug "executing #{rsync_cmd}"

			system rsync_cmd \
				or raise "Error #{$?.exitstatus} executing #{rsync_cmd}"

			# run bundle install

			ssh_args = [
				"ssh",
				"-q",
				"-T",
				"-A",
				"-S", "#{work_dir}/ssh/#{host_name}.sock",
				"-o", "BatchMode=yes",
				"root@#{host_hostname}",
				[
					"cd /zattikka-hq",
					"mkdir -p .override",
					"ln -sfd /zattikka-hq/alchemy-hq .override/alchemy-hq",
					[
						"bundle install",
						"--path .gems",
						"--binstubs .stubs",
						"--local",
						"--without rrd development",
						"--quiet",
					].join(" "),
				].join("; "),
			]

			ssh_cmd =
				esc_shell ssh_args

			logger.debug "executing #{ssh_cmd}"

			ssh_success =
				system ssh_cmd

			raise "Error: #{ssh_cmd}" \
				unless ssh_success

		end

	end

	def run_on_host host_name, cmd, redirect = ""

		host_elem =
			abstract["deploy-host"] \
				.find_first("deploy-host [@name = '#{host_name}']")

		host_hostname = host_elem.attributes["hostname"]
		ssh_args = %W[
			ssh -q -T -A
			-S #{WORK}/ssh/#{host_name}.sock
			-o BatchMode=yes
			root@#{host_hostname}
			#{esc_shell cmd}
		]
		ssh_cmd = "#{esc_shell ssh_args} </dev/null #{redirect}"
		logger.debug "executing #{ssh_cmd}"
		tmp = system ssh_cmd
		return tmp

	end

	def run_self_on_host host_name, args

		# build command

		remote_args = [
			"/#{deploy_dir}/.stubs/#{remote_command}",
			"--log", "trace:raw",
			*args,
		]

		remote_cmd =
			esc_shell remote_args

		host_elem =
			abstract["deploy-host"] \
				.find_first("deploy-host [@name = #{esc_xp host_name}]")

		host_hostname =
			host_elem["hostname"]

		ssh_args = [
			"ssh",
			"-q",
			"-T",
			"-A",
			"-S", "#{work_dir}/ssh/#{host_name}.sock",
			"-o", "BatchMode=yes",
			"root@#{host_hostname}",
			remote_cmd,
		]

		ssh_cmd =
			esc_shell ssh_args

		# execute it

		logger.debug "executing #{ssh_cmd}"

		pipe_read, pipe_write =
			IO.pipe

		pid = fork do

			pipe_read.close

			$stdin.reopen "/dev/null", "r"

			$stdout.reopen pipe_write
			$stderr.reopen pipe_write

			exec *ssh_args

		end

		pipe_write.close

		# process output

		while line = pipe_read.gets

			begin

				data =
					MultiJson.load line

			rescue => e
				$stderr.print line
				next
			end

			begin

				data["content"].each do
					|item|

					logger.output \
						item,
						data["mode"].to_sym

				end

			rescue => e
				puts "Error outputting log message:"
				require "pp"
				pp data
			end

		end

		# check result and return

		Process.wait pid

		return $?.exitstatus == 0

	end

	def deploy hosts
		if $series || hosts.size <= 1
			deploy_series hosts
		else
			deploy_parallel hosts
		end
	end

	def deploy_series hosts

		logger.notice "performing deployments in series"

		# fix perms first

		fix_perms

		# deploy per host

		error = false

		hosts.each do
			|host|

			logger.notice "deploy #{host}"

			begin

				if host == "local"

					HQ::Deploy::Slave.go \
						"host/local/deploy.xml"

				else

					send_to host

					args = [
						"server-deploy",
						host,
						"host/#{host}/deploy.xml",
					]

					unless run_self_on_host host, args
						logger.error "deploy #{host} failed"
						error = true
					end

				end

			rescue => e

				logger.error "deploy #{host} failed: #{e.message}"
				logger.detail "#{e.to_s}\n#{e.backtrace.join("\n")}"

				error = true

				break

			end

		end

		if error
			logger.error "errors detected during one or more deployments"
		else
			logger.notice "all deployments completed successfully"
		end
	end

	def deploy_parallel hosts

		# fix perms first
		fix_perms

		# queue is used to enforce maximum threads as configured

		max_threads =
			(config.find_first("deploy")["threads"] || 10).to_i

		logger.notice \
			"performing deployments in parallel, #{max_threads} threads"

		queue = SizedQueue.new max_threads

		# lock is used for output to stop things clobbering each other

		lock = Mutex.new

		# threads are collected so they can be waited on

		threads = []

		# error is set to true if any part fails in any thread

		error = false

		# deploy per host

		hosts.each do |host|

			queue.push :token

			threads << Thread.new do

				begin
					if host == "local"

						require "hq/deploy/slave"

						deploy_slave =
							HQ::Deploy::Slave.new

						deploy_slave.logger = logger

						deploy_slave.hostname = hostname
						deploy_slave.config_dir = config_dir
						deploy_slave.work_dir = work_dir
						deploy_slave.deploy_path = "host/local/deploy.xml"

						deploy_slave.go

					else

						send_to host

						args = [
							"server-deploy",
							host,
							"host/#{host}/deploy.xml",
						]

						success =
							run_self_on_host \
								host,
								args

						unless success
							logger.error "deploy #{host} failed"
							error = true
						end

					end

				rescue => e

					lock.synchronize do
						logger.error "deploy #{host} failed: #{e.message}"
						logger.detail "#{e.to_s}\n#{e.backtrace.join("\n")}"
						error = true
					end

				ensure
					queue.pop
				end

			end

		end

		# wait for all threads to complete

		threads.each { |thread| thread.join }

		# check for error and output appropriate message

		if error
			logger.die "errors detected during one or more deployments"
		else
			logger.notice "all deployments completed successfully"
		end

	end

	def run_command hosts, command

		logger.notice "running command on hosts"

		hosts.each do |host|
			logger.notice "running on #{host}"
			run_self_on_host host, [ "server-run", command ]
		end

	end

end
