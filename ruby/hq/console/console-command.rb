module HQ
module Console
class ConsoleCommand

	attr_accessor :hq

	def config_dir() hq.config_dir end
	def logger() hq.logger end

	def go command_name

		require "mandar/console"

		Mandar.logger = logger
		Object.const_set "CONFIG", config_dir

		Mandar::Console::Server.new.run

	end

end
end
end
