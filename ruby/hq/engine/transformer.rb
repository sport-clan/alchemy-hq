module HQ
module Engine
class Transformer

	attr_accessor :parent

	def logger() parent.logger end
	def xquery_client() parent.xquery_client end

	def config_dir() parent.config_dir end
	def work_dir() parent.work_dir end

	attr_accessor :input_docs
	attr_accessor :schema_elems

	attr_reader :results
	attr_reader :rules

	def load_rules

		logger.debug "loading transformation rules"

		@rules = {}

		Dir.glob("#{config_dir}/rules/**/*").each do
			|filename|

			next unless filename =~ /^
				#{Regexp.quote "#{config_dir}/rules/"}
				(
					(.+)
					\. (xquery)
				)
			$/x

			rule = {}
			rule[:name] = $2
			rule[:type] = $3
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

	def get_record_id_short record_elem

		schema_elem =
			@schema_elems["schema/#{record_elem.name}"]

		unless schema_elem
			raise "No schema for #{record_elem.name}"
		end

		id_parts =
			schema_elem.find("id/*").to_a.map do
				|id_elem|

				part =
					record_elem[id_elem["name"]]

				unless part
					raise "No #{id_elem["name"]} for #{record_elem.name}"
				end

				part

			end

		id =
			id_parts.join "/"

		return id

	end

	def get_record_id_long record_elem

		return "%s/%s" % [
			record_elem.name,
			get_record_id_short(record_elem),
		]

	end

	def rebuild

		logger.notice "performing transformation"

		logger.time "performing transformation" do

			load_rules

			load_input_into_results
			load_input_into_data

			@xquery_session =
				xquery_client.session

			load_includes

			remove_output

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

	def load_input_into_results

		@results = {}

		@input_docs.each do
			|name, input_doc|

			@results[name] = {
				:doc => input_doc,
			}

		end

	end

	def load_input_into_data

		@data = {}

		@input_docs.each do
			|name, input_doc|

			input_doc.root.each_element do
				|input_elem|

				record_id =
					get_record_id_long input_elem

				@data[record_id] =
					input_elem

			end

		end

	end

	def load_includes

		include_dir =
			"#{config_dir}/include"

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

		if File.directory? "#{work_dir}/output"
			FileUtils.remove_entry_secure "#{work_dir}/output"
		end

		FileUtils.mkdir "#{work_dir}/output"

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
				@schema_elems.keys
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

		rules_for_pass.each do
			|rule_name, rule|

			@remaining_rules.delete rule_name

			rebuild_one rule

		end

		return rules_for_pass.size

	end

	def rebuild_one rule

		rule_name = rule[:name]
		rule_type = rule[:type]

		logger.debug "rebuilding rule #{rule_name}"
		logger.time "rebuilding rule #{rule_name}" do

			# setup rule

			doc = XML::Document.new
			doc.root = XML::Node.new "data"

			rule[:in].each do
				|in_name|

				result = @results[in_name]

				unless result
					logger.debug "No rule result for #{in_name}, " \
						+ "requested by #{rule_name}"
					next
				end

				result[:doc].root.each do
					|elem|
					doc.root << doc.import(elem)
				end

			end

			@xquery_session.set_library_module \
				"input.xml",
				doc.to_s

			# perform query

			begin

				@xquery_session.compile_xquery \
					rule[:source]

				rule[:str] = \
					@xquery_session.run_xquery \
						"<xml/>"

			rescue => e
				logger.error e.to_s
				logger.detail e.backtrace.join("\n")
				FileUtils.touch "#{work_dir}/error-flag"
				raise "error compiling #{rule[:path]}"
			end

			# process output

			rule[:doc] =
				XML::Document.string \
					rule[:str],
					:options => XML::Parser::Options::NOBLANKS

			rule[:result] = {}

			rule[:out].each do
				|out|
				rule[:result][out] = []
			end

			rule[:doc].root.find("*").each do
				|elem|

				unless rule[:out].include? elem.name
					raise "rule %s created invalid output type %s" % [
						rule_name,
						elem.name,
					]
				end

				rule[:result][elem.name] << elem

			end

			# write output

			FileUtils.mkdir_p "#{work_dir}/output/#{rule_name}"

			rule[:result].each do
				|result_name, elems|

				doc = XML::Document.new
				doc.root = XML::Node.new "data"
				elems.each { |elem| doc.root << doc.import(elem) }
				doc.save "#{work_dir}/output/#{rule_name}/#{result_name}.xml"

			end

			# add output to data

			rule[:result].each do
				|result_name, elems|

				elems.each do
					|elem|

					begin

						record_id =
							get_record_id_long elem

					rescue => e

						logger.die "record id error for %s created by %s" % [
							elem.name,
							rule_name,
						]

					end

					if @data[record_id]
						raise "duplicate record id #{record_id}"
					end

					@data[record_id] =
						elem

				end

			end

			# add output to results

			rule[:result].each do |result_name, elems|
				set_result result_name, elems
			end

		end

	end

	def set_result name, elems

		result = @results[name]

		unless result

			result = {}

			result[:doc] = XML::Document.new
			result[:doc].root = XML::Node.new "data"

			@results[name] = result

		end

		doc = result[:doc]

		elems.each do
			|elem|
			doc.root << doc.import(elem)
		end

	end

	def load_results

		@results = {}

		Dir[
			"#{work_dir}/output/**/*.xml",
			"#{work_dir}/input/*.xml",
		].each do
			|path|

			result_name =
				File.basename path, ".xml"

			result_doc =
				XML::Document.file \
					path,
					:options => XML::Parser::Options::NOBLANKS

			set_result \
				result_name,
				result_doc.root.find("*")

		end

	end

end
end
end
