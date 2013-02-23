module HQ
module Deploy

	def self.register_commands hq

		hq.register_command \
			"config",
			"TARGET...",
			"Write config for named targets (host, class, all)" \
		do
			require "hq/deploy/config-command"
			command = HQ::Deploy::ConfigCommand.new
			command.hq = hq
			command
		end

		hq.register_command \
			"deploy",
			"TARGET...",
			"Deploy to named targets (host, class, all)" \
		do
			require "hq/deploy/deploy-command"
			command = HQ::Deploy::DeployCommand.new
			command.hq = hq
			command
		end

		hq.register_command \
			"local-deploy" \
		do
			require "hq/deploy/local-deploy-command"
			command = HQ::Deploy::LocalDeployCommand.new
			command.hq = hq
			command
		end

		hq.register_command \
			"server-deploy" \
		do
			require "hq/deploy/server-deploy-command"
			command = HQ::Deploy::ServerDeployCommand.new
			command.hq = hq
			command
		end

	end

end
end
