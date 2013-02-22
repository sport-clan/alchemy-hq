module HQ
module Deploy
class ServerDeployCommand

	attr_accessor :hq

	def go command_name, hostname, deploy_path

		require "hq/deploy/slave"

		# write hostname

		hq.hostname = hostname

		File.open "/etc/hq-hostname", "w" do
			|file|
			file.puts hostname
		end

		# perform deployment

		deploy_slave =
			HQ::Deploy::Slave.new

		deploy_slave.hq = hq
		deploy_slave.deploy_path = deploy_path

		deploy_slave.go

	end

end
end
end
