require "hq/deploy/utils"

module HQ
module Deploy
class DeployCommand

	include HQ::Deploy::Utils

	attr_accessor :hq

	def engine() hq.engine end
	def logger() hq.logger end

	def go command_name, *targets

		hq.hostname = "master"

		# check args

		$deploy_role \
			or logger.die "must specify --role in deploy mode"

		# message about mock

		logger.warning "running in mock deployment mode" \
			if $mock

		# create deploy_master

		require "hq/deploy/master"

		deploy_master = HQ::Deploy::Master.new
		deploy_master.hq = hq

		# begin staged/rollback deploy

		deploy_master.stager_start \
			$deploy_mode,
			$deploy_role,
			$mock \
		do

			filtered_hosts = nil

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

			logger.time "deploy", :detail do

				# and deploy

				deploy_master.deploy filtered_hosts

			end

		end

	end

end
end
end
