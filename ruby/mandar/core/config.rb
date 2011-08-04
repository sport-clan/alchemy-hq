module Mandar::Core::Config

	@data_docs = {}
	@data_strs = {}

	def self.reload()
		mandar true
		config true
		service true
	end

	def self.mandar(reload = false)
		(@config_lock ||= Mutex.new).synchronize do

			# use cached copy
			return @mandar_config if @mandar_config unless reload

			require "xml"

			# check file exists
			mandar_config_file = "#{CONFIG}/mandar-config.xml"
			File.exists? mandar_config_file or Mandar.die "File does not exist #{mandar_config_file}"

			# parse document
			doc = XML::Document.file mandar_config_file, :options =>XML::Parser::Options::NOBLANKS

			# validate document
			#relax = Mandar::Core::Config.load_relax_ng "#{MANDAR}/etc/mandar-config.rnc"
			#doc.validate_relaxng relax

			# save and return
			return @mandar_config = doc.root
		end
	end

	def self.profile()
		mandar = Mandar::Core::Config.mandar
		(@config_lock ||= Mutex.new).synchronize do
			return @profile if @profile
			$profile or Mandar.die "Must specify --profile"
			profile = mandar.find_first("profile[@name='#{$profile}']")
			profile or Mandar.die "No such profile: #{$profile}"
			return @profile = profile
		end
	end

	def self.abstract
		return @abstract if @abstract
		abstract = {}
		Mandar::Engine::Abstract.results.each do |result_name, result|
			abstract[result_name] = result[:doc].root
		end
		return @abstract = abstract
	end

	def self.service(reload = false)
		(@service_lock ||= Mutex.new).synchronize do
			return @service if @service unless reload
			dir = "#{WORK}/concrete/#{Mandar.host}"
			return @service = load_and_merge(dir, "service")
		end
	end

	def self.load_and_merge(dir, name)

		# create document
		ret = XML::Document.new
		ret.root = XML::Node.new name

		# scan directory
		if File.directory? dir
			Dir.new(dir).each do |file|
				next unless file =~ /^([^.].*)\.xml$/

				# load xml
				XML::default_line_numbers = true
				doc = XML::Document.file "#{dir}/#{file}", :options =>XML::Parser::Options::NOBLANKS

				# merge it in
				doc.root.find("*").each do |elem|
					new_elem = ret.import(elem)
					new_elem.attributes["loaded-from"] = file
					ret.root << new_elem
				end
			end
		end

		return ret
	end

	def self.loaded_from(elem)
		while elem
			return elem.attributes["loaded-from"] if elem.attributes["loaded-from"]
			elem = elem.parent
		end
		return "unknown"
	end

	def self.field_to_xml(schemas_elem, fields_elem, value, elem)
		value = {} unless value.is_a? Hash
		fields_elem.find("* [name() != 'option']").each do |field_elem|
			field_name = field_elem.attributes["name"]
			case field_elem.name
			when "text", "int", "ts-update"
				elem.attributes[field_name] = value[field_name].to_s
			when "bigtext"
				prop = XML::Node.new field_name
				prop << value[field_name]
				elem << prop
			when "bool"
				elem.attributes[field_name] = "yes" if value[field_name]
			when "list"
				items = value[field_name] || []
				items.each do |item|
					prop = XML::Node.new field_name
					field_to_xml schemas_elem, field_elem, item, prop
					elem << prop
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
				raise "unexpected element #{field_elem.name} found in field list for schema #{schemas_elem.attributes["name"]}"
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

	def self.staged_change()
		return nil unless $deploy_mode == :staged

		locks = Mandar.cdb.get("mandar-locks")
		return nil unless locks

		change = locks["changes"][$deploy_role]
		return nil unless change

		return change
	end

	def self.stager_start(deploy_mode, deploy_role, deploy_mock)
		[ :unstaged, :staged, :rollback ].include? deploy_mode \
			or raise "Invalid mode: #{deploy_mode}"

		mode_text = {
			:unstaged => "unstaged deploy",
			:staged => "staged deploy",
			:rollback => "rollback"
		} [deploy_mode]

		# control differences between staged deploy and rollback
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
		locks = Mandar.cdb.get("mandar-locks")
		locks or raise "Internal error"

		# check for concurrent deployment
		locks["deploy"] \
			and Mandar.die "another deployment is in progress for role #{locks["deploy"]["role"]}"

		# check for concurrent changes
		locks["changes"].each do |role, change|
			next if change["state"] == "stage"
			next if change["role"] == deploy_role && deploy_mode != :unstaged
			Mandar.die "another deployment has uncommited changes for role #{role}"
		end

		# find our changes
		if deploy_mode != :unstaged
			change = locks["changes"][deploy_role]
			change or Mandar.die "no staged changes for #{deploy_role}"
			[ "stage", "done" ].include? change["state"] \
				or Mandar.die "pending changes in invalid state #{change["state"]} for role " +
					"#{deploy_role}"
		end

		# display confirmation
		Mandar.notice "beginning #{mode_text} for role #{deploy_role}"

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

		# save locks
		Mandar.cdb.update locks

		at_exit do

			# load locks
			locks = Mandar.cdb.get("mandar-locks")
			locks or raise "Internal error"

			# check seq
			locks["deploy"]["seq"] = lock_seq or Mandar.die "Lock sequence number changed"

			# clear lock
			locks["deploy"] = nil

			unless deploy_mock
				if deploy_mode != :unstaged

					# find our changes
					change = locks["changes"][deploy_role]
					change or raise "Internal error"
					change["state"] == change_pending_state or raise "Internal error"

					# update change state
					change["state"] = change_done_state
					change[change_done_timestamp] = Time.now.to_i

				end
			end

			# save locks
			Mandar.cdb.update locks

			# display confirmation
			Mandar.notice "finished #{mode_text} changes for role #{deploy_role}"
		end
	end

	def self.js_to_xml(schemas_elem, schema_elem, value)
		elem = XML::Node.new schema_elem.attributes["name"]
		field_to_xml(schemas_elem, schema_elem.find_first("id"), value, elem)
		field_to_xml(schemas_elem, schema_elem.find_first("fields"), value, elem)
		return elem
	end

	def self.data_dump()

		Mandar.notice "dumping data"

		require "xml"

		start_time = Time.now

		@data_docs = {}
		@data_strs = {}

		FileUtils.remove_entry_secure "#{WORK}/data" if File.directory? "#{WORK}/data"
		FileUtils.mkdir_p "#{WORK}/data", :mode => 0700

		schemas_doc = XML::Document.file "#{WORK}/schema.xml", :options =>XML::Parser::Options::NOBLANKS
		schemas_elem = schemas_doc.root
		rows = Mandar.cdb.view("root", "by_type")["rows"]
		values_by_type = Hash.new
		rows.each do |row|
			next unless row["value"]["mandar_type"]
			values_by_type[row["value"]["mandar_type"]] ||= Hash.new
			values_by_type[row["value"]["mandar_type"]][row["id"]] = row["value"]
		end

		change = staged_change

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

			File.open "#{WORK}/data/#{schema_name}.xml", "w" do |f|
				f.print data_str
			end

			@data_docs[schema_name] = data_doc
			@data_strs[schema_name] = data_str
		end

		end_time = Time.now
		Mandar.trace "dumping data took #{((end_time - start_time) * 1000).to_i}ms"
	end

	def self.data_load

		Mandar.notice "loading data"

		require "xml"

		start_time = Time.now

		@data_docs = {}
		@data_strs = {}

		schemas_elem = XML::Parser.file("#{WORK}/schema.xml").parse.root

		schemas_elem.find("schema").each do |schema_elem|
			schema_name = schema_elem.attributes["name"]

			data_path = "#{WORK}/data/#{schema_name}.xml"
			if File.exist? data_path
				data_doc = XML::Document.file data_path, :options => XML::Parser::Options::NOBLANKS
				data_str = data_doc.to_s
			else
				data_str = "<data/>"
				data_doc = XML::Document.string data_str, :options => XML::Parser::Options::NOBLANKS
			end

			@data_docs[schema_name] = data_doc
			@data_strs[schema_name] = data_str
		end

		end_time = Time.now
		Mandar.trace "loading data took #{((end_time - start_time) * 1000).to_i}ms"
	end

	def self.warn_no_config
		return false unless $no_config
		return true if @warned
		Mandar.warning "not rebuilding configuration due to --no-config option"
		@warned = true
		return true
	end

	def self.rebuild_abstract
		return if warn_no_config

		# ensure schema doc exists and remember it
		schema_file = "#{WORK}/schema.xml"
		unless File.exists? schema_file
			Mandar.trace "writing schema.xml (empty)"
			FileUtils.mkdir_p WORK
			File.open schema_file, "w" do |f|
				f.print "<schemas/>"
			end
		end
		old_schema_data = File.read(schema_file)

		# process abstract config, repeat until schema is consistent
		while true

			if $no_database
				Mandar.warning "not dumping data due to --no-database option"
				data_load
			else
				data_dump
			end

			# process abstract config
			Mandar::Engine::Abstract.rebuild @data_docs

			# write new schema file
			Mandar.trace "writing schema.xml"
			Tempfile.open("mandar") do |f|
				doc = XML::Document.new
				doc.root = XML::Node.new "schemas"

				%W[ schema schema-option ].each do |elem_name|
					schema_result = Mandar::Engine::Abstract.results[elem_name]
					if schema_result
						schema_result[:doc].root.find(elem_name).each do |schema_elem|
							doc.root << doc.import(schema_elem)
						end
					end
				end
				f.puts doc.to_s
				FileUtils.move f.path, schema_file
			end

			# if schema file hasn't changed then we're done, otherwise start again
			new_schema_data = File.read(schema_file)
			break if new_schema_data == old_schema_data
			old_schema_data = new_schema_data
			Mandar.notice "restart due to schema changes"
		end
	end

	def self.rebuild_concrete(host_names = nil)
		return if warn_no_config
		unless host_names
			host_names = [ "local" ]
			abstract["host"].each do |host_elem|
				host_names << host_elem.attributes["name"]
			end
		end
		abstract_results = Mandar::Engine::Abstract.results
		Mandar::Engine::Concrete.rebuild abstract_results, host_names
	end

	def self.load_relax_ng(filename)
		unless FileUtils.uptodate? "#{filename}.rng", [ filename ]
			Tempfile.open "mandar-" do |tmp|
				system "trang -I rnc -O rng #{filename} #{tmp.path}" \
					or Mandar.die "Error converting #{filename}"
				FileUtils.mv tmp.path, "#{filename}.rng"
			end
		end
		return XML::RelaxNG.document(XML::Document.file("#{filename}.rng"))
	end

end
