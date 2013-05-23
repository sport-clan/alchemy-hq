module HQ
module Misc

	def self.register_commands hq

		hq.register_command \
			"db-schema",
			nil,
			"Update database design documents" \
		do
			require "hq/misc/db-schema-command"
			command = DbSchemaCommand.new
			command.hq = hq
			command
		end

	end

end
end
