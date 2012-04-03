module Mandar::Engine::Concrete

	def self.load_source
		return if @concretes

		Mandar.debug "loading concrete sources"
		concretes = {}

		start_time = Time.now

		Dir.new("#{CONFIG}/concrete").each do |filename|
			next unless filename =~ /^([a-z0-9]+(?:-[a-z0-9]+)*)\.(xslt|xquery)$/
			Mandar.trace "loading #{filename}"
			concrete = {}
			concrete[:name] = $1
			concrete[:type] = $2
			concrete[:path] = "#{CONFIG}/concrete/#{filename}"
			concrete[:source] = File.read concrete[:path]
			concrete[:in] = []
			concrete[:source].scan(/\(: (in) ([a-z0-9]+(?:-[a-z0-9]+)*) :\)$/).each do |type, name|
				concrete[type.to_sym] << name
			end
			concrete[:source].gsub!(/\(: include ([a-z0-9]+(?:-[a-z0-9]+)*) :\)$/) do |match|
				include_path = "#{CONFIG}/include/#{$1}.#{concrete[:type]}"
				File.exists? include_path or raise "Include file not found #{$1}.#{concrete[:type]}"
				File.read(include_path).gsub("\n", " ").strip
			end
			concretes[concrete[:name]] = concrete
		end

		end_time = Time.now
		Mandar.trace "loading concrete sources took #{((end_time - start_time) * 1000).to_i}ms"

		return @concretes = concretes
	end

	def self.rebuild abstract_results, hosts

		zorba = Mandar::Engine.zorba
		data_manager = Mandar::Engine.data_manager

		load_source

		Mandar.notice "rebuilding concrete config"

		start_time = Time.now

		# create directories
		FileUtils.remove_entry_secure "#{WORK}/concrete" if File.directory? "#{WORK}/concrete"
		FileUtils.mkdir "#{WORK}/concrete"
		hosts.each do |host|
			FileUtils.mkdir "#{WORK}/concrete/#{host}"
		end

		@concretes.each do |concrete_name, concrete|

			Mandar.debug "rebuilding concrete config #{concrete_name}"

			# compile xquery
			# TODO bug?
			#xquery = Mandar::Engine.zorba.compileQuery(concrete[:source])

			# setup abstract
			doc = XML::Document.new
			doc.root = XML::Node.new "abstract"
			concrete[:in].each do |abstract_name|
				unless result = abstract_results[abstract_name]
					Mandar.debug "No abstract result for #{abstract_name}, requested by #{concrete_name}"
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
				Mandar::Engine.config_client.set_document "abstract.xml", doc.to_s
			end

			unless zorba
				Mandar::Engine.config_client.compile_xslt concrete[:path]
			end

			hosts.each do |host|

				Mandar.debug "rebuilding concrete config #{concrete_name} for #{host}"

				# set hostname
				if zorba
					docIter = data_manager.parseXML "<host-name value=\"#{host}\"/>"
					docIter.open
					item = Zorba_api::Item::createEmptyItem
					docIter.next item
					docIter.destroy
					data_manager.getDocumentManager.put "host-name.xml", item
				else
					Mandar::Engine.config_client.set_document "host-name.xml", "<host-name value=\"#{host}\"/>"
				end

				# perform trasnformation
				if zorba
					begin
						xquery = zorba.compileQuery(concrete[:source])
					rescue => e
						Mandar.error "#{e.to_s}"
						raise "error compiling concrete/#{concrete_name}.xquery"
					end
					begin
						ret = xquery.execute()
					rescue => e
						Mandar.error "#{e.to_s}"
						raise "error processing concrete #{concrete_name} for #{host}"
					end
					xquery.destroy()
				else
					ret = Mandar::Engine.config_client.execute_xslt
				end

				# save doc
				doc = XML::Document.string ret, :options => XML::Parser::Options::NOBLANKS
				doc.save "#{WORK}/concrete/#{host}/#{concrete_name}.xml"

				# remove hostname
				if zorba
					data_manager.getDocumentManager.remove "host-name.xml"
				end

			end

			# clean up
			#xquery.destroy()
			if zorba
				data_manager.getDocumentManager.remove "abstract.xml"
			else
				Mandar::Engine.config_client.reset
			end

		end

		end_time = Time.now
		Mandar.trace "rebuilding concrete config took #{((end_time - start_time) * 1000).to_i}ms"

	end

end
