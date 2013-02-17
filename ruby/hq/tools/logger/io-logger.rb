require "hq/tools/logger"

class HQ::Tools::Logger::IoLogger

	attr_accessor :out

	def fix_stuff old_stuff, content, prefix = nil

		content = {} \
			unless content.is_a? Hash

		new_stuff = {
			hostname: content["hostname"] || old_stuff[:hostname],
			level: (content["level"] || old_stuff[:level]).to_sym,
			prefix: (old_stuff[:prefix] || "") + (prefix || ""),
		}

		raise "No hostname" \
			unless new_stuff[:hostname]

		raise "No level" \
			unless new_stuff[:level]

		return new_stuff

	end

end
