module HQ
module Tools
class Logger
class IoLogger

	attr_accessor :out
	attr_accessor :level

	def fix_stuff old_stuff, content, prefix = nil

		content = {} \
			unless content.is_a? Hash

		new_stuff = {
			hostname: content["hostname"] || old_stuff[:hostname],
			level: (content["level"] || old_stuff[:level]).to_sym,
			prefix: (old_stuff[:prefix] || "") + (prefix || ""),
			mode: old_stuff[:mode].to_sym,
		}

		raise "No hostname" \
			unless new_stuff[:hostname]

		raise "No level" \
			unless new_stuff[:level]

		return new_stuff

	end

	def output content, stuff = {}, prefix = ""

		stuff = fix_stuff stuff, content, prefix

		# check we want to output this entry

		return unless HQ::Tools::Logger.level_includes \
			level,
			stuff[:level]

		return unless valid_modes.include? stuff[:mode].to_sym

		# output it

		output_real content, stuff

	end

end
end
end
end
