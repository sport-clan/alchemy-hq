class HQ::Deploy::Slave

	include Mandar::Tools::Escape

	attr_accessor :deploy_path

	def self.go deploy_path

		deploy_slave =
			new

		deploy_slave.deploy_path =
			deploy_path

		deploy_slave.go

	end

	def go

		create_alchemy_hq_link

		read_deploy_xml

		write_hostname

		read_tasks
		process_tasks
		sort_tasks

		sub_tasks_hack

		run_tasks

	end

	def create_alchemy_hq_link

		# TODO does this belong here?

		# TODO do this with ruby, not bash

		system \
			"test -h /alchemy-hq " +
			"|| ln -s #{Mandar.deploy_dir}/alchemy-hq /alchemy-hq"

	end

	def write_hostname

		# TODO remove this
		File.unlink "/etc/mandar-hostname" \
			if File.exist? "/etc/mandar-hostname"

		File.open "/etc/hq-hostname", "w" do |f|

			f.puts \
				@deploy_elem.attributes["host"]

		end

	end

	def read_deploy_xml

		deploy_doc =
			XML::Document.file \
				"#{CONFIG}/.work/deploy/#{@deploy_path}"

		deploy_doc \
			or raise "Error"

		@deploy_elem =
			deploy_doc.root

	end

	def read_tasks

		@tasks_doc =
			XML::Document.new

		@tasks_doc.root =
			XML::Node.new "tasks"

		@deploy_elem.find("file").each do |file_elem|

			file_name =
				file_elem.attributes["name"]

			full_path =
				"#{WORK}/deploy/#{file_name}"

			tasks_doc = \
				XML::Document.string \
					File.read(full_path),
					:options => XML::Parser::Options::NOBLANKS

			tasks_doc.root.find("*").each do |elem|

				@tasks_doc.root <<
					@tasks_doc.import(elem)

			end

		end

	end

	def process_tasks

		@tasks_by_name = Hash[
			@tasks_doc.root.find("task").map do |task_elem|
				[ task_elem.attributes["name"], task_elem ]
			end
		]

		@task_deps = {}

		@tasks_by_name.each do |task_name, task_elem|
			@task_deps[task_name] ||= []
		end

		@tasks_by_name.each do |task_name, task_elem|

			task_after =
				task_elem.attributes["after"]

			task_before =
				task_elem.attributes["before"]

			if task_after
				task_after.to_s.strip.split(/\s+/).each do |after_name|

					@task_deps[after_name] \
						or raise "No such task #{after_name} mentioned in " +
							"after list for #{task_name}"

					@task_deps[task_name] <<
						after_name

				end
			end

			if task_before
				task_before.to_s.strip.split(/\s+/).each do |before_name|

					@task_deps[before_name] \
						or raise "No such task #{before_name} mentioned in " +
							"before list for #{task_name}"

					@task_deps[before_name] <<
						task_name

				end
			end

		end

	end

	def sort_tasks

		@task_order = []

		while @task_deps.length > 0

			progress = false

			@task_deps =
				Hash[@task_deps.sort]

			@task_deps.each do |task_name, deps|

				next if (deps - @task_deps.keys).length < deps.length

				@task_order << task_name
				@task_deps.delete task_name

				progress = true

			end

			progress \
				or raise "Unable to resolve task dependencies"

		end

	end

	def sub_tasks_hack

		# TODO evil globals

		# TODO should not be sub task specific

		$sub_tasks_by_task = Hash[
			@tasks_doc.root.find("sub-task").map do |sub_task_elem|
				[
					sub_task_elem.attributes["task"],
					sub_task_elem
				]
			end
		]

	end

	def run_tasks

		@task_order.each do |task_name|

			Mandar.debug "deploying #{task_name}"

			Mandar.time "deploying #{task_name}" do

				begin

					Mandar::Deploy::Commands.perform \
						@tasks_by_name[task_name]

				rescue => e

					Mandar.error "error during deployment of #{task_name}"
					Mandar.error e.inspect
					Mandar.error e.backtrace

					exit 1

				end

			end
		end
	end

end
