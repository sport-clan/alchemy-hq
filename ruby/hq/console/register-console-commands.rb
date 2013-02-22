module HQ
module Console

	def self.register_commands hq

		hq.register_command \
			"console",
			nil,
			"Run HTTP console and API" \
		do
			require "hq/console/console-command"
			command = HQ::Console::ConsoleCommand.new
			command.hq = hq
			command
		end

		hq.register_command \
			"console-config",
			nil,
			"Write config file for console" \
		do
			require "hq/console/console-config-command"
			command = HQ::Console::ConsoleConfigCommand.new
			command.hq = hq
			command
		end

	end

end
end
