require "hq/tools/escape"

require "yaml"

module HQ
module Deploy
class Master

	attr_accessor :hq

	def config() hq.config end
	def config_dir() hq.config_dir end
	def couch() hq.couch end
	def deploy_dir() hq.deploy_dir end
	def engine() hq.engine end
	def em_wrapper() hq.em_wrapper end
	def hostname() hq.hostname end
	def logger() hq.logger end
	def mq_wrapper() hq.mq_wrapper end
	def profile() hq.profile end
	def remote_command() hq.remote_command end
	def work_dir() hq.work_dir end

	include HQ::Tools::Escape

	def initialize
		require "tempfile"
	end

	def controller

		return @controller if @controller

		require "hq/deploy/controller"

		@controller =
			HQ::Deploy::Controller.new

		@controller.master = self

		return @controller

	end

	def write host_names

		abstract_results =
			engine.results

		# write concrete config

		logger.notice "writing deploy config"

		logger.time "writing deploy config" do

			FileUtils.remove_entry_secure "#{work_dir}/deploy" \
				if File.directory? "#{work_dir}/deploy"

			FileUtils.mkdir "#{work_dir}/deploy"
			FileUtils.mkdir "#{work_dir}/deploy/host"
			FileUtils.mkdir "#{work_dir}/deploy/class"

			# write out deploy docs

			class_names = []

			host_names.each do
				|host_name|

				FileUtils.mkdir "#{work_dir}/deploy/host/#{host_name}"

				deploy_host_elem =
					abstract_results["deploy-host"][:doc] \
						.find_first "deploy-host [@name = #{esc_xp host_name}]"

				deploy_host_elem \
					or raise "No deploy-host found for #{host_name}"

				host_class =
					deploy_host_elem.attributes["class"]

				if host_class
					class_names << host_class \
						unless class_names.include? host_class
				end

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
					"#{work_dir}/deploy/host/#{host_name}/deploy.xml"

			end

			# sort tasks into appropriate hosts and classes

			task_elems = {}

			[ "task", "sub-task" ].each do
				|type|

				next unless abstract_results[type]

				abstract_results[type][:doc] \
					.find("/*/#{type}")
					.each \
				do
					|task_elem|

					target_key = [
						task_elem["target-type"],
						task_elem["target-name"],
					].join "/"

					task_key = [
						task_elem.name,
						task_elem["name"],
					].join "/"

					target_task_elems = task_elems[target_key] ||= {}
					raise "Duplicate task" if target_task_elems[task_key]
					target_task_elems[task_key] = task_elem

				end

			end

			# write out tasks

			task_elems.sort.each do
				|target_key, target_task_elems|

				target_type, target_name =
					target_key.split "/"

				doc = XML::Document.new
				doc.root = XML::Node.new "tasks"

				target_task_elems.sort.each do
					|task_name, task_elem|
					doc.root << doc.import(task_elem)
				end

				tasks_path =
					"%s/deploy/%s/%s/tasks.xml" % [
						work_dir,
						target_type,
						target_name,
					]

				FileUtils.mkdir_p \
					File.dirname(tasks_path)

				doc.save tasks_path

			end

		end

	end

	def stager_start \
			deploy_mode,
			deploy_role,
			deploy_mock,
			&proc

		[ :unstaged, :staged, :rollback ].include? deploy_mode \
			or raise "Invalid mode: #{deploy_mode}"

		# create mq logger

		require "hq/mq/mq-logger"

		mq_logger = HQ::MQ::MqLogger.new
		mq_logger.em_wrapper = em_wrapper
		mq_logger.mq_wrapper = mq_wrapper
		mq_logger.deploy_id = $deploy_id
		mq_logger.start

		logger.add_logger mq_logger

		mode_text = {
			:unstaged => "unstaged deploy",
			:staged => "staged deploy",
			:rollback => "rollback"
		} [deploy_mode]

		# control differences between staged deploy and rollback

		# attempt to work around segfaults
		change_pending_state = nil

		unless deploy_mode == :unstaged
			change_pending_state = {
				:staged => "deploy",
				:rollback => "rollback"
			} [deploy_mode]
			change_done_state = {
				:staged => "done",
				:rollback => "stage"
			} [deploy_mode]
			change_start_timestamp = {
				:staged => "deploy-timestamp",
				:rollback => "rollback-timestamp",
			} [deploy_mode]
			change_done_timestamp = {
				:staged => "done-timestamp",
				:rollback => "rollback-done-timestamp",
			} [deploy_mode]
		end

		# load locks

		locks = couch.get "mandar-locks"
		locks or raise "Internal error"

		# check for concurrent deployment

		locks["deploy"] \
			and logger.die "another deployment is in progress for role " +
				"#{locks["deploy"]["role"]}"

		# check for concurrent changes

		locks["changes"].each do |role, change|

			next if change["state"] == "stage"
			next if change["role"] == deploy_role && deploy_mode != :unstaged

			logger.die "another deployment has uncommited changes for role " +
				"#{role}"

		end

		# find our changes

		if deploy_mode != :unstaged

			change = locks["changes"][deploy_role]
			change or logger.die "no staged changes for #{deploy_role}"

			[ "stage", "done" ].include? change["state"] \
				or logger.die "pending changes in invalid state " +
					"#{change["state"]} for role #{deploy_role}"

		end

		# display confirmation

		logger.notice "beginning #{mode_text} for role #{deploy_role}"

		# allocate seq

		lock_seq = locks["next-seq"]
		locks["next-seq"] += 1

		# create lock

		locks["deploy"] = {
			"role" => deploy_role,
			"host" => Socket.gethostname,
			"timestamp" => Time.now.to_i,
			"type" => deploy_mode.to_s,
			"seq" => lock_seq,
			"mock" => deploy_mock,
		}

		# update change state

		unless deploy_mock
			if deploy_mode != :unstaged
				change["state"] = change_pending_state
				change[change_start_timestamp] = Time.now.to_i
			end
		end

		# save locks

		couch.update locks

		begin

			# yield to caller

			proc.call

		ensure

			# load locks

			locks = couch.get "mandar-locks"
			locks or raise "Internal error"

			# check seq

			if ! locks["deploy"]
				logger.error "Lock deploy vanished"
			end

			if locks["deploy"]["seq"] != lock_seq
				logger.error "Lock sequence number changed"
			end

			# clear lock

			locks["deploy"] = nil

			unless deploy_mock
				if deploy_mode != :unstaged

					# find our changes

					change =
						locks["changes"][deploy_role]

					change \
						or raise "Internal error"

					change["state"] == change_pending_state \
						or raise "Internal error"

					# update change state

					change["state"] = change_done_state
					change[change_done_timestamp] = Time.now.to_i

				end
			end

			# save locks

			couch.update locks

			# display confirmation

			logger.notice "finished #{mode_text} for role #{deploy_role}"

			# publish end of deployment

			mq_logger.stop

		end

	end

	def fix_perms

		logger.debug "fixing permissions"

		logger.time "fixing permissions" do

			# projects dir must be 0755

			projects_dir =
				File.expand_path "..", config_dir

			system esc_shell [
				"chmod",
				"0755",
				projects_dir,
			] or raise "Error"

			# everything should only be owner writable but world readable

			system esc_shell [
				"chmod",
				"--recursive",
				"u=rwX,og=rX",
				config_dir,
			] or raise "Error"

			# with the exception of .work which is only owner readable

			system esc_shell [
				"chmod",
				"--recursive",
				"u=rwX,og=",
				"#{config_dir}/.work",
			]

		end

	end

	def deploy hosts
		fix_perms
		controller.deploy hosts
	end

	def transform
		dump_db
		engine.transform
	end

	def dump_db

		logger.notice "loading input from database"

		logger.time "loading input from database" do

			change = staged_change

			# add existing records

			rows =
				couch.view("root", "by_type")["rows"].map {
					|view_row|

					id = view_row["id"][8..-1]
					type = view_row["value"]["type"]
					value = view_row["value"]["value"]

					# handle updates and deletes

					if change && change_item = change["items"][id]
						next if change_item["action"] == "delete"
						raise "Error" unless change_item["action"] == "update"
						value = change_item["record"]
					end

					{
						"id" => id,
						"type" => type,
						"value" => value,
					}

				}.compact

			# handle creates

			if change

				change["items"].values.each do
					|change_item|

					next unless change_item["action"] == "create"

					value = change_item["record"]
					id = value["_id"]
					type = value["mandar_type"]

					value.delete "_id"
					value.delete "mandar_type"
					value.delete "_rev"

					rows << {
						"id" => id,
						"type" => type,
						"value" => value,
					}

				end

			end

			FileUtils.mkdir_p work_dir

			File.open "#{work_dir}/input.yaml", "w" do
				|file_io|
				file_io.write YAML.dump rows
			end

		end

	end

	def staged_change

		return nil \
			unless $deploy_mode == :staged

		locks =
			couch.get "mandar-locks"

		return nil \
			unless locks

		change =
			locks["changes"][$deploy_role]

		return nil \
			unless change

		return change

	end

end
end
end

# ex:set ts=4 noet:
