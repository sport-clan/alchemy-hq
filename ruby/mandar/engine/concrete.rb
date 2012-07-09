module Mandar::Engine::Concrete

	def self.load_source
		return if @concretes

		Mandar.debug "loading concrete sources"
		concretes = {}

		start_time = Time.now

		Dir.new("#{CONFIG}/concrete").each do |filename|

			filename_regex =
				/^([a-z0-9]+(?:-[a-z0-9]+)*)\.(xquery)$/

			next unless filename =~ filename_regex

			Mandar.trace "loading #{filename}"

			concrete = {}

			concrete[:name] = $1
			concrete[:type] = $2
			concrete[:path] = "#{CONFIG}/concrete/#{filename}"
			concrete[:source] = File.read concrete[:path]
			concrete[:in] = []

			decl_regex =
				/\(: (in) ([a-z0-9]+(?:-[a-z0-9]+)*) :\)$/

			concrete[:source].scan(decl_regex).each do |type, name|
				concrete[type.to_sym] << name
			end

			concretes[concrete[:name]] = concrete

		end

		end_time = Time.now
		time_ms = ((end_time - start_time) * 1000).to_i
		Mandar.timing "loading concrete sources took #{time_ms}ms"

		return @concretes = concretes
	end

	def self.rebuild abstract_results, hosts

		begin

			xquery_client = Mandar::Engine.xquery_client
			if xquery_client
				xquery_session = xquery_client.session
			end

			load_source

			Mandar.notice "rebuilding concrete config"

			start_time = Time.now

			# create directories

			FileUtils.remove_entry_secure "#{WORK}/concrete" \
				if File.directory? "#{WORK}/concrete"

			FileUtils.mkdir "#{WORK}/concrete"
			FileUtils.mkdir "#{WORK}/concrete/host"
			FileUtils.mkdir "#{WORK}/concrete/class"

			hosts.each do |host|
				FileUtils.mkdir "#{WORK}/concrete/host/#{host}"
				FileUtils.mkdir "#{WORK}/concrete/host/#{host}/concrete"
				FileUtils.mkdir "#{WORK}/concrete/host/#{host}/abstract"
			end

			# load xquery modules

			include_dir = "#{CONFIG}/include"

			Dir["#{include_dir}/*.xquery"].each do |path|
				path =~ /^ #{Regexp.quote include_dir} \/ (.+) $/x
				name = $1
				text = File.read path
				xquery_session.set_library_module name, text
			end

			@concretes.each do |concrete_name, concrete|

				Mandar.debug "rebuilding concrete config #{concrete_name}"

				Mandar.time "rebuilding concrete config #{concrete_name}" do

					# compile xquery
					# TODO bug?
					#xquery = Mandar::Engine.zorba.compileQuery(concrete[:source])

					# setup abstract

					doc = XML::Document.new
					doc.root = XML::Node.new "abstract"

					concrete[:in].each do |abstract_name|
						unless result = abstract_results[abstract_name]
							Mandar.debug "No abstract result for " +
								"#{abstract_name}, requested by #{concrete_name}"
							next
						end
						result[:doc].root.each do |elem|
							doc.root << doc.import(elem)
						end
					end

					xquery_session.set_library_module \
						"abstract.xml",
						doc.to_s

					# compile

					begin
						xquery_session.compile_xquery \
							concrete[:source]
					rescue => e
						Mandar.error e.to_s
						raise "error compiling #{concrete[:path]}"
					end

					# process

					hosts.each do |host|

						Mandar.debug "rebuilding concrete config " +
							"#{concrete_name} for #{host}"

						Mandar.time "rebuilding concrete config " +
							"#{concrete_name} for #{host}" do

							# set hostname

							xquery_session.set_library_module \
								"host-name.xml",
								"<host-name value=\"#{host}\"/>"

							# perform trasnformation

							begin
								ret =
									xquery_session.run_xquery \
										"<xml/>"
							rescue => e
								Mandar.error e.to_s
								raise "error running #{concrete[:path]}"
							end

							# save doc

							temp =
								XML::Document.string \
									ret,
									:options => XML::Parser::Options::NOBLANKS

							doc =
								XML::Document.new

							doc.root =
								XML::Node.new "concrete"

							temp.find("/*/*").each do |elem|
								doc.root << doc.import(elem)
							end

							doc.save "#{WORK}/concrete/host/#{host}/concrete/#{concrete_name}.xml"

						end
					end

				end

			end

		ensure

			xquery_client.close if xquery_client

		end

		end_time = Time.now
		time_ms = ((end_time - start_time) * 1000).to_i
		Mandar.timing "rebuilding concrete config took #{time_ms}ms"

	end

end
