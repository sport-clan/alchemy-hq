module HQ
module Deploy
class LocalDeployCommand

	attr_accessor :hq

	def deploy_slave() hq.deploy_slave end

	def go _, deploy_path

		hq.hostname = "local"

		require "hq/deploy/slave"

		deploy_slave =
			HQ::Deploy::Slave.new

		deploy_slave.hq = hq
		deploy_slave.deploy_path = deploy_path

		deploy_slave.go

	end

end
end
end
