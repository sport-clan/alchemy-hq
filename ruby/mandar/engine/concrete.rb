module Mandar::Engine::Concrete

	def self.rebuild abstract_results, hosts

		# write concrete config

		Mandar.notice "writing concrete config"

		Mandar.time "writing concrete config" do

			FileUtils.remove_entry_secure "#{WORK}/concrete" \
				if File.directory? "#{WORK}/concrete"

			FileUtils.mkdir "#{WORK}/concrete"
			FileUtils.mkdir "#{WORK}/concrete/host"
			FileUtils.mkdir "#{WORK}/concrete/class"

			# create output documents for each host

			concrete_docs = {}
			hosts.each do |host|
				doc = XML::Document.new
				doc.root = XML::Node.new "concrete"
				concrete_docs[host] = doc
			end

			# sort tasks into appropriate host documents

			abstract_results["task"][:doc] \
					.find("/*/task") \
					.each do |task_elem|

				host = task_elem.attributes["host"]
				doc = concrete_docs[host]
				next unless doc

				doc.root << doc.import(task_elem)

			end

			# write out new documents

			concrete_docs.each do |host, concrete_doc|

				FileUtils.mkdir "#{WORK}/concrete/host/#{host}"

				concrete_doc.save \
					"#{WORK}/concrete/host/#{host}/tasks.xml"

			end

		end

	end

end
