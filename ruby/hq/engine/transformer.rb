require "hq/engine/libxmlruby-mixin"

module HQ
module Engine
class Transformer

	include LibXmlRubyMixin

	attr_accessor :parent

	def logger() parent.logger end
	def xquery_client() parent.xquery_client end

	attr_accessor :schema_file
	attr_accessor :rules_dir
	attr_accessor :include_dir
	attr_accessor :input_dir
	attr_accessor :output_dir

	attr_reader :data

	def load_schema

		@schemas =
			load_schema_file schema_file

	end

	def load_rules

		logger.debug "loading transformation rules"

		@rules = {}

		Dir.glob("#{rules_dir}/**/*").each do
			|filename|

			next unless filename =~ /^
				#{Regexp.quote "#{rules_dir}/"}
				(
					(.+)
					\. (xquery)
				)
			$/x

			rule = {}
			rule[:name] = $2
			rule[:type] = $3
			rule[:filename] = "#{$2}.#{$3}"
			rule[:path] = filename
			rule[:source] = File.read rule[:path]
			rule[:in] = []
			rule[:out] = []
			rule[:source].scan(
				/\(: (in|out) ([a-z0-9]+(?:-[a-z0-9]+)*) :\)$/
			).each do |type, name|
				rule[type.to_sym] << name
			end

			@rules[rule[:name]] = rule

		end

		@rules = Hash[@rules.sort]

	end

	def init_xquery_session

		@xquery_session =
			xquery_client.session

		# add hq module
		# TODO move this somewhere

		@xquery_session.set_library_module \
			"hq",
			"
				module namespace hq = \"hq\";

				declare function hq:get (
					$id as xs:string
				) as element () ?
				external;

				declare function hq:get (
					$type as xs:string,
					$id-parts as xs:string *
				) as element () ?
				external;

				declare function hq:find (
					$type as xs:string
				) as element () *
				external;
			"

	end

	def rebuild

		logger.notice "performing transformation"

		logger.time "performing transformation" do

			remove_output

			init_xquery_session

			@data = {}

			load_schema
			load_rules
			load_input
			load_includes

			@remaining_rules =
				@rules.clone

			pass_number = 0

			loop do

				num_processed =
					rebuild_pass pass_number

				break if num_processed == 0

				pass_number += 1

			end

		end

		return {
			:success => @remaining_rules.empty?,
			:remaining_rules => @remaining_rules.keys,
			:missing_types =>
				(
					@remaining_rules
						.values
						.map { |rule| rule[:in] }
						.flatten
						.uniq
						.sort
				) - (
					@schema_types
						.to_a
						.select { |type| type =~ /^schema\// }
						.map { |type| type.gsub /^schema\//, "" }
				)
		}

	end

	def load_input

		logger.debug "reading input from disk"

		logger.time "reading input from disk" do

			Dir["#{input_dir}/*.xml"].each do
				|filename|

				input_data =
					load_data_file filename

				input_data.each do
					|item_dom|

					store_data item_dom

				end

			end

		end

	end

	def load_includes

		Dir["#{include_dir}/*.xquery"].each do
			|path|

			path =~ /^ #{Regexp.quote include_dir} \/ (.+) $/x
			name = $1

			@xquery_session.set_library_module \
				name,
				File.read(path)

		end

	end

	def remove_output

		if File.directory? output_dir
			FileUtils.remove_entry_secure output_dir
		end

		FileUtils.mkdir output_dir

	end

	def rebuild_pass pass_number

		logger.debug "beginning pass #{pass_number}"

		@incomplete_types =
			Set.new(
				@remaining_rules.map {
					|rule_name, rule|
					rule[:out]
				}.flatten.uniq.sort
			)

		@schema_types =
			Set.new(
				@schemas.keys
			)

		rules_for_pass =
			Hash[
				@remaining_rules.select do
					|rule_name, rule|

					missing_input_types =
						rule[:in].select {
							|in_type|
							@incomplete_types.include? in_type
						}

					missing_input_schemas =
						rule[:in].select {
							|in_type|
							! @schema_types.include? "schema/#{in_type}"
						}

					missing_output_schemas =
						rule[:out].select {
							|out_type|
							! @schema_types.include? "schema/#{out_type}"
						}

					result = [
						missing_input_types,
						missing_input_schemas,
						missing_output_schemas,
					].flatten.empty?

					messages = []

					messages << "incomplete inputs: %s" % [
						missing_input_types.join(", "),
					] unless missing_input_types.empty?

					messages << "missing input schemas: %s" % [
						missing_input_schemas.join(", "),
					] unless missing_input_schemas.empty?

					messages << "missing output schemas: %s" % [
						missing_output_schemas.join(", "),
					] unless missing_output_schemas.empty?

					unless messages.empty?
						logger.debug "rule %s: %s" % [
							rule_name,
							messages.join("; "),
						]
					end

					result

				end
			]

		num_processed = 0

		rules_for_pass.each do
			|rule_name, rule|

			used_types =
				rebuild_one rule

			missing_types =
				used_types.select {
					|type|
					@incomplete_types.include? type
				}

			raise "Error" unless missing_types.empty?

			if missing_types.empty?
				@remaining_rules.delete rule_name
				num_processed += 1
			end

		end

		return num_processed

	end

	def rebuild_one rule

		rule_name = rule[:name]
		rule_type = rule[:type]

		logger.debug "rebuilding rule #{rule_name}"
		logger.time "rebuilding rule #{rule_name}" do

			# perform query

			used_types = Set.new
			result_str = nil

			begin

				@xquery_session.compile_xquery \
					rule[:source],
					rule[:filename]

				result_str =
					@xquery_session.run_xquery \
						"<xml/>" \
				do
					|name, args|

					case name

					when "get record by id"
						args["id"] =~ /^([^\/]+)\//
						used_types << $1
						record = @data[args["id"]]
						record ? [ record ] : []

					when "get record by id parts"
						used_types << args["type"]
						id = [ args["type"], *args["id parts"] ].join "/"
						record = @data[id]
						record ? [ record ] : []

					when "search records"
						used_types << args["type"]
						regex = /^#{Regexp.escape args["type"]}\//
						@data \
							.select { |id, record| id =~ regex }
							.sort
							.map { |id, record| record }

					else
						raise "No such function #{name}"

					end

				end

#puts "USED: #{used_types.to_a.join " "}"
#puts "INCOMPLETE: #{@incomplete_types.to_a.join " "}"
				missing_types = used_types & @incomplete_types
puts "MISSING: #{missing_types.to_a.join " "}" unless missing_types.empty?
				return missing_types unless missing_types.empty?

			rescue XQuery::XQueryError => exception

				logger.die "%s:%s:%s %s" % [
					exception.file,
					exception.line,
					exception.column,
					exception.message
				]

			rescue => exception
				logger.error "%s: %s" % [
					exception.class,
					exception.to_s,
				]
				logger.detail exception.backtrace.join("\n")
				FileUtils.touch "#{work_dir}/error-flag"
				raise "error compiling #{rule[:path]}"
			end

			# process output

			result_doms =
				load_data_string result_str

			result_doms.each do
				|item_dom|

				begin

					item_id =
						get_record_id_long \
							@schemas,
							item_dom

				rescue => e

					logger.die "record id error for %s created by %s" % [
						item_dom.name,
						rule_name,
					]

				end

				store_data item_dom

			end

			return []

		end

	end

	def store_data item_dom

		# determine id

		item_id =
			get_record_id_long \
				@schemas,
				item_dom

		if @data[item_id]
			raise "duplicate record id #{item_id}"
		end

		# store in memory

		item_xml =
			to_xml_string item_dom

		@data[item_id] =
			item_xml

		# store in filesystem

		item_path =
			"#{output_dir}/data/#{item_id}.xml"

		item_dir =
			File.dirname item_path

		FileUtils.mkdir_p \
			item_dir

		File.open item_path, "w" do
			|file_io|
			file_io.puts item_xml
		end

	end

end
end
end
