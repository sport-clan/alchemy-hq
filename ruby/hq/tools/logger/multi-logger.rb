require "hq/tools/logger"

class HQ::Tools::Logger::MultiLogger

	def initialize
		@loggers = []
	end

	def add_logger logger
		@loggers << logger
	end

	def output content, stuff, prefix = ""
		@loggers.each do
			|logger|
			logger.output content, stuff, prefix
		end
	end

end
