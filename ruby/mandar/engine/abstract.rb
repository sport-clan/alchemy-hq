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

		Dir.new("#{CONFIG}/abstract").each do |filename|
			next unless filename =~ /^([a-z0-9]+(?:-[a-z0-9]+)*)\.(xslt|xquery)$/
			abstract = {}
			abstract[:name] = $1
			abstract[:type] = $2
			abstract[:path] = "#{CONFIG}/abstract/#{filename}"
			abstract[:source] = File.read abstract[:path]
			abstract[:in] = []
			abstract[:out] = []
			abstract[:data] = []
			abstract[:source].scan(/\(: (data|in|out) ([a-z0-9]+(?:-[a-z0-9]+)*) :\)$/).each do |type, name|
				abstract[type.to_sym] << name
			end
			abstract[:source].gsub!(/\(: include ([a-z0-9]+(?:-[a-z0-9]+)*) :\)$/) do |match|
				include_path = "#{CONFIG}/include/#{$1}.#{abstract[:type]}"
				File.exists? include_path or raise "Include file not found #{$1}.#{abstract[:type]}"
				File.read(include_path).gsub("\n", " ").strip
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
			abstract[:data] = rule.find("inputs/data").to_a.map { |elem| elem.attributes["name"] }
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
		@results = {}

		start_time = Time.now

		# remove existing
		FileUtils.remove_entry_secure "#{WORK}/abstract" if File.directory? "#{WORK}/abstract"
		FileUtils.mkdir "#{WORK}/abstract"

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
				rebuild_one data_docs, abstract

			end

			Mandar.die "circular dependency in abstract: #{remaining.keys.sort.join ", "}" unless num_processed > 0
		end

		end_time = Time.now
		Mandar.trace "rebuilding abstract took #{((end_time - start_time) * 1000).to_i}ms"

	end

	def self.rebuild_one data_docs, abstract
		abstract_name = abstract[:name]

		zorba = Mandar::Engine.zorba
		data_manager = Mandar::Engine.data_manager

		config_client = Mandar::Engine.config_client unless zorba

		Mandar.debug "rebuilding abstract #{abstract_name}"

		start_time = Time.now

		# setup abstract
		doc = XML::Document.new
		doc.root = XML::Node.new "abstract"
		abstract[:in].each do |in_name|
			unless result = @results[in_name]
				Mandar.warning "No abstract result for #{in_name}, requested by #{abstract_name}"
				next
			end
			result[:doc].root.each { |elem| doc.root << doc.import(elem) }
		end
		if zorba
			docIter = data_manager.parseXML doc.to_s
			docIter.open
			item = Zorba_api::Item::createEmptyItem
			docIter.next item
			docIter.destroy
			data_manager.getDocumentManager.put "abstract.xml", item
		else
			config_client.set_document "abstract.xml", doc.to_s
		end

		# setup data
		doc = XML::Document.new
		doc.root = XML::Node.new "data"
		abstract[:data].each do |data_name|
			unless data_doc = data_docs[data_name]
				data_doc or Mandar.warning "no data for #{data_name}, requested by #{abstract_name}"
				next
			end
			data_doc.root.each { |elem| doc.root << doc.import(elem) }
		end
		if zorba
			docIter = data_manager.parseXML doc.to_s
			docIter.open
			item = Zorba_api::Item::createEmptyItem
			docIter.next item
			docIter.destroy
			data_manager.getDocumentManager.put "data.xml", item
		else
			config_client.set_document "data.xml", doc.to_s
		end

		if zorba

			# compile xquery
			begin
				xquery = Mandar::Engine.zorba.compileQuery(abstract[:source])
			rescue => e
				Mandar.error "#{e.to_s}"
				raise "error compiling abstract/#{abstract_name}.xquery"
			end

			# execute query
			begin
				abstract[:str] = xquery.execute()
			rescue => e
				Mandar.error "#{e.to_s}"
				raise "error processing abstract/#{abstract_name}.xquery"
			end

			# clean up
			xquery.destroy()
			data_manager.getDocumentManager.remove "abstract.xml"
			data_manager.getDocumentManager.remove "data.xml"

		else

			begin
				config_client.compile_xslt abstract[:path]
			rescue => e
				Mandar.error e.to_s
				Mandar.error "deleting #{WORK}"
				FileUtils.rm_rf "#{WORK}"
				raise "error compiling #{abstract[:path]}"
			end

			abstract[:str] = config_client.execute_xslt
			config_client.reset

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

		end_time = Time.now
		Mandar.trace "rebuilding abstract #{abstract_name} took #{((end_time - start_time) * 1000).to_i}ms"
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
