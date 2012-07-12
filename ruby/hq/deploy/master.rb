class HQ::Deploy::Master

	include Mandar::Tools::Escape

	def write abstract_results, host_names

		# write concrete config

		Mandar.notice "writing deploy config"

		Mandar.time "writing deploy config" do

			FileUtils.remove_entry_secure "#{WORK}/deploy" \
				if File.directory? "#{WORK}/deploy"

			FileUtils.mkdir "#{WORK}/deploy"
			FileUtils.mkdir "#{WORK}/deploy/host"
			FileUtils.mkdir "#{WORK}/deploy/class"

			# write out deploy docs

			class_names = []

			host_names.each do |host_name|

				FileUtils.mkdir "#{WORK}/deploy/host/#{host_name}"

				deploy_host_elem =
					abstract_results["deploy-host"][:doc] \
						.find_first "deploy-host [@name = #{xp host_name}]"

				deploy_host_elem \
					or raise "No deploy-host found for #{host_name}"

				host_class =
					deploy_host_elem.attributes["class"]

				class_names << host_class \
					unless class_names.include? host_class

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
					"#{WORK}/deploy/host/#{host_name}/deploy.xml"

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
							raise "Error"
					end

					next unless doc

					doc.root << doc.import(task_elem)

				end

			end

			# write out tasks

			host_docs.each do |host_name, host_doc|

				host_doc.save \
					"#{WORK}/deploy/host/#{host_name}/tasks.xml"

			end

			class_docs.each do |class_name, class_doc|

				FileUtils.mkdir \
					"#{WORK}/deploy/class/#{class_name}"

				class_doc.save \
					"#{WORK}/deploy/class/#{class_name}/tasks.xml"

			end

		end

	end

end
