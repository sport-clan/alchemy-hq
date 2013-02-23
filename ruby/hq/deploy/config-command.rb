require "hq/deploy/utils"

module HQ
module Deploy
class ConfigCommand

	include HQ::Deploy::Utils

	attr_accessor :hq

	def engine() hq.engine end
	def logger() hq.logger end

	def go command_name, *targets

		hq.hostname = "master"

		# create deploy master

		require "hq/deploy/master"

		deploy_master = HQ::Deploy::Master.new
		deploy_master.hq = hq

		logger.time "transform", :detail do

			# rebuild config

			engine.transform

			# determine list of hosts to deploy to

			targetted_hosts =
				process_targets targets

			# reduce list of hosts on various criteria

			filtered_hosts =
				filter_hosts \
					targetted_hosts,
					"deploying to",
					targets

			# output processed config

			deploy_master.write filtered_hosts

		end

	end

end
end
end
