module HQ
module Engine
class Transformer

	attr_accessor :logger
	attr_accessor :xquery_client

	attr_accessor :config_dir
	attr_accessor :work_dir

	def initialize
		@abstracts = nil
		@results = nil
	end

	def results
		load_results unless @results
		return @results
	end

	def load_source

		logger.debug "loading abstract sources"
		abstracts = {}

		Dir.glob("#{config_dir}/abstract/**/*").each do |filename|

			next unless filename =~ /^
				#{Regexp.quote "#{config_dir}/abstract/"}
				(
					(.+)
					\. (xquery)
				)
			$/x

			abstract = {}
			abstract[:name] = $2
			abstract[:type] = $3
			abstract[:path] = filename
			abstract[:source] = File.read abstract[:path]
			abstract[:in] = []
			abstract[:out] = []
			abstract[:source].scan(
				/\(: (in|out) ([a-z0-9]+(?:-[a-z0-9]+)*) :\)$/
			).each do |type, name|
				abstract[type.to_sym] << name
			end
			abstracts[abstract[:name]] = abstract

		end

		return @abstracts = abstracts
	end

	def rebuild data_docs

		load_source

		logger.notice "rebuilding abstract"

		# set up results with data

		@results = {}

		data_docs.each do |name, data_doc|
			@results[name] = {
				:doc => data_doc,
			}
		end

		logger.time "rebuilding abstract" do

			# create session

			xquery_session = xquery_client.session

			# send include files

			include_dir = "#{config_dir}/include"
			Dir["#{include_dir}/*.xquery"].each do |path|
				path =~ /^ #{Regexp.quote include_dir} \/ (.+) $/x
				name = $1
				text = File.read path
				xquery_session.set_library_module name, text
			end

			# remove existing

			FileUtils.remove_entry_secure "#{work_dir}/abstract" \
				if File.directory? "#{work_dir}/abstract"

			FileUtils.mkdir "#{work_dir}/abstract"

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

				logger.die "circular dependency in abstract: " +
					"#{remaining.keys.sort.join ", "}" \
					unless num_processed > 0
			end


		end

	end

	def rebuild_one xquery_session, data_docs, abstract

		abstract_name = abstract[:name]
		abstract_type = abstract[:type]

		logger.debug "rebuilding abstract #{abstract_name}"
		logger.time "rebuilding abstract #{abstract_name}" do

			# setup abstract

			doc = XML::Document.new
			doc.root = XML::Node.new "abstract"

			abstract[:in].each do |in_name|

				result = @results[in_name]

				unless result
					logger.debug "No abstract result for #{in_name}, " \
						+ "requested by #{abstract_name}"
					next
				end

				result[:doc].root.each do
					|elem| doc.root << doc.import(elem)
				end

			end

			xquery_session.set_library_module \
				"abstract.xml",
				doc.to_s

			# perform query

			begin

				xquery_session.compile_xquery \
					abstract[:source]

				abstract[:str] = \
					xquery_session.run_xquery \
						"<xml/>"

			rescue => e
				logger.error e.to_s
				logger.detail e.backtrace
				FileUtils.touch "#{work_dir}/error-flag"
				raise "error compiling #{abstract[:path]}"
			end

			# delete and/or create

			FileUtils.mkdir_p "#{work_dir}/abstract/#{abstract_name}"

			# process output

			abstract[:doc] =
				XML::Document.string \
					abstract[:str],
					:options => XML::Parser::Options::NOBLANKS

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
				doc.save "#{work_dir}/abstract/#{abstract_name}/#{result_name}.xml"
			end

			# add output to results

			abstract[:result].each do |result_name, elems|
				set_result result_name, elems
			end

		end

	end

	def set_result name, elems
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

	def load_results

		@results = {}

		Dir[
			"#{work_dir}/abstract/**/*.xml",
			"#{work_dir}/data/*.xml",
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
