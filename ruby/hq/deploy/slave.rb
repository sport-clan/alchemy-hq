require "hq/tools/escape"

class HQ::Deploy::Slave

	include HQ::Tools::Escape

	attr_accessor :hq
	attr_accessor :deploy_path

	def config_dir() hq.config_dir end
	def hostname() hq.hostname end
	def logger() hq.logger end
	def work_dir() hq.work_dir end

	def go

		read_deploy_xml

		read_tasks
		process_tasks
		sort_tasks

		sub_tasks_hack

		run_tasks

	end

	def read_deploy_xml

		deploy_doc =
			XML::Document.file \
				"#{config_dir}/.work/deploy/#{deploy_path}"

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
				"#{work_dir}/deploy/#{file_name}"

			next \
				unless File.exist? full_path

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

		# TODO should check for duplicate task names

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

		require "mandar"
		Mandar.logger = logger
		Mandar.host = hostname

		@task_order.each do |task_name|

			logger.debug "deploying #{task_name}"

			logger.time "deploying #{task_name}" do

				begin

					Mandar::Deploy::Commands.perform \
						@tasks_by_name[task_name]

				rescue => e

					logger.output({
						"type" => "exception",
						"level" => "error",
						"hostname" => hostname,
						"text" => "error during deployment of #{task_name}",
						"message" => e.message,
						"backtrace" => e.backtrace,
					})

					exit 1

				end

			end
		end
	end

end
