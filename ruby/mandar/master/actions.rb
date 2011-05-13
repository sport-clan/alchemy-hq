module Mandar::Master::Actions

	def self.register(target, type, *actions)
		@actions ||= {}
		actions.each do |action|
			key = { :type => type, :action => action }
			@actions[key] and raise "Duplicate action #{action} on #{type}"
			@actions[key] = { :target => target }
		end
	end

	def self.perform(cdb, record)
		type = record["mandar_type"].to_sym
		action = record["action"].to_sym
		key = { :type => type, :action => action }
		@actions[key] or raise "Unrecognised action #{action} on #{type}"
		target = @actions[key][:target]
		target.send "#{type}_#{action}", cdb, record
	end

end
