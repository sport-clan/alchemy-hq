module Mandar::Engine::Abstract

	@abstracts = nil
	@results = nil

	def self.results
		load_results unless @results
		return @results
	end

	def self.load_source

		Mandar.debug "loading abstract sources"
		abstracts = {}

		Dir.glob("#{CONFIG}/abstract/**/*").each do |filename|

			next unless filename =~ /^
				#{Regexp.quote "#{CONFIG}/abstract/"}
				(
					(.+)
					\. (xslt|xquery)
				)
			$/x

			abstract = {}
			abstract[:name] = $2
			abstract[:type] = $3
			abstract[:path] = filename
			abstract[:source] = File.read abstract[:path]
			abstract[:in] = []
			abstract[:out] = []
			abstract[:source].scan(/\(: (in|out) ([a-z0-9]+(?:-[a-z0-9]+)*) :\)$/).each do |type, name|
				abstract[type.to_sym] << name
			end
			abstracts[abstract[:name]] = abstract

		end

		FileUtils.rm_rf "#{WORK}/abstract-rules"
		FileUtils.mkdir_p "#{WORK}/abstract-rules"
		Mandar::Core::Config.schemas_elem.find("abstract-rule[@enabled='yes']").each do |rule|
			abstract = {}
			abstract[:name] = rule.attributes["name"]
			abstract[:type] = rule.attributes["type"]
			abstract[:path] = "#{WORK}/abstract-rules/#{abstract[:name]}.#{abstract[:type]}"
			abstract[:source] = rule.find "string(source)"
			abstract[:in] = rule.find("inputs/abstract").to_a.map { |elem| elem.attributes["name"] }
			abstract[:out] = rule.find("outputs/abstract").to_a.map { |elem| elem.attributes["name"] }
			abstracts[abstract[:name]] = abstract
			File.open(abstract[:path], "w") { |f| f.print abstract[:source] }
		end

		return @abstracts = abstracts
	end

	def self.rebuild data_docs

		load_source

		Mandar.notice "rebuilding abstract"

		# set up results with data

		@results = {}

		data_docs.each do |name, data_doc|
			@results[name] = {
				:doc => data_doc,
			}
		end

		Mandar.time "rebuilding abstract" do

			begin

				# setup xquery

				xquery_client = Mandar::Engine.xquery_client
				if xquery_client

					# create session

					xquery_session = xquery_client.session

					# send include files

					include_dir = "#{CONFIG}/include"
					Dir["#{include_dir}/*.xquery"].each do |path|
						path =~ /^ #{Regexp.quote include_dir} \/ (.+) $/x
						name = $1
						text = File.read path
						xquery_session.set_library_module name, text
					end

				end

				# remove existing

				FileUtils.remove_entry_secure "#{WORK}/abstract" if File.directory? "#{WORK}/abstract"
				FileUtils.mkdir "#{WORK}/abstract"

				# do it

				remaining = @abstracts.clone
				until remaining.empty?

					pending = Set.new
					remaining.each do |abstract_name, abstract|
						pending.merge abstract[:out]
					end

					num_processed = 0
					remaining.each do |abstract_name, abstract|

						# check dependencies

						next if abstract[:in].find { |name| pending.include? name }

						remaining.delete abstract_name
						num_processed += 1

						# do it

						rebuild_one xquery_session, data_docs, abstract

					end

					Mandar.die "circular dependency in abstract: #{remaining.keys.sort.join ", "}" unless num_processed > 0
				end

			ensure
				xquery_client.close if xquery_client
			end

		end

	end

	def self.rebuild_one xquery_session, data_docs, abstract
		abstract_name = abstract[:name]
		abstract_type = abstract[:type]

		xslt2_client = Mandar::Engine.xslt2_client

		Mandar.debug "rebuilding abstract #{abstract_name}"
		Mandar.time "rebuilding abstract #{abstract_name}" do

			# setup abstract

			doc = XML::Document.new
			doc.root = XML::Node.new "abstract"

			abstract[:in].each do |in_name|

				result = @results[in_name]

				unless result
					Mandar.warning "No abstract result for #{in_name}, requested by #{abstract_name}"
					next
				end

				result[:doc].root.each do
					|elem| doc.root << doc.import(elem)
				end

			end

			case abstract_type

				when "xquery"
					xquery_session.set_library_module "abstract.xml", doc.to_s

				when "xslt"
					xslt2_client.set_document "abstract.xml", doc.to_s

				else
					raise "Error"
			end

			# perform query

			case abstract_type

				when "xquery"

					begin

						xquery_session.compile_xquery \
							abstract[:source]

						abstract[:str] = \
							xquery_session.run_xquery \
								"<xml/>"

					rescue => e
						Mandar.error e.to_s
						Mandar.error "deleting #{WORK}"
						FileUtils.rm_rf "#{WORK}"
						raise "error compiling #{abstract[:path]}"
					end

				when "xslt"

					begin
						xslt2_client.compile_xslt abstract[:path]
					rescue => e
						Mandar.error e.to_s
						Mandar.error "deleting #{WORK}"
						FileUtils.rm_rf "#{WORK}"
						raise "error compiling #{abstract[:path]}"
					end

					abstract[:str] = xslt2_client.execute_xslt
					xslt2_client.reset

				else
					raise "Error"

			end

			# delete and/or create

			FileUtils.mkdir_p "#{WORK}/abstract/#{abstract_name}"

			# process output

			abstract[:doc] = XML::Document.string abstract[:str], :options => XML::Parser::Options::NOBLANKS
			abstract[:result] = {}
			abstract[:out].each { |out| abstract[:result][out] = [] }
			abstract[:doc].root.find("*").each do |elem|
				abstract[:out].include? elem.name or \
					raise "Abstract #{abstract_name} created invalid output type #{elem.name}"
				abstract[:result][elem.name] << elem
			end

			# write output

			abstract[:result].each do |result_name, elems|
				doc = XML::Document.new
				doc.root = XML::Node.new "abstract"
				elems.each { |elem| doc.root << doc.import(elem) }
				doc.save "#{WORK}/abstract/#{abstract_name}/#{result_name}.xml"
			end

			# add output to results

			abstract[:result].each do |result_name, elems|
				set_result result_name, elems
			end

		end

	end

	def self.set_result name, elems
		result = @results[name]
		unless result
			result = {}
			result[:doc] = XML::Document.new
			result[:doc].root = XML::Node.new "abstract"
			@results[name] = result
		end
		doc = result[:doc]
		elems.each { |elem| doc.root << doc.import(elem) }
	end

	def self.load_results
		@results = {}
		Dir.new("#{WORK}/abstract").each do |abstract_name|
			next unless abstract_name =~ /^[a-z0-9]+(?:-[a-z0-9]+)*$/
			abstract = []
			Dir.new("#{WORK}/abstract/#{abstract_name}").each do |result_filename|
				next unless result_filename =~ /^([a-z0-9]+(?:-[a-z0-9]+)*)\.xml$/
				result_name = $1
				result_doc = XML::Document.file "#{WORK}/abstract/#{abstract_name}/#{result_filename}",
					:options => XML::Parser::Options::NOBLANKS
				set_result result_name, result_doc.root.find("*")
			end
		end
	end

end
