module HQ
module Core

	def self.register_commands hq

		hq.register_command \
			"listen",
			nil,
			"Continually display activity" \
		do
			require "hq/core/listen-command"
			command = HQ::Core::ListenCommand.new
			command.hq = hq
			command
		end

	end

end
end
