module HQ
module Engine

	def self.register_commands hq

		hq.register_command \
			"unlock",
			nil,
			"Unlock crashed deployment" \
		do
			require "hq/engine/unlock-command"
			command = HQ::Engine::UnlockCommand.new
			command.hq = hq
			command
		end

	end

end
end
