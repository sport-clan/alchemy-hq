module Mandar::Deploy::Commands

	def self.register(target, *commands)
		@commands ||= {}
		commands.each do |command|
			@commands[command] and raise "Duplicate command #{command}"
			@commands[command] = { :target => target }
		end
	end

	def self.perform(parent_elem)
		parent_elem.find("*").each do |elem|
			command_name = elem.name.gsub("-", "_").to_sym
			command = @commands[command_name]
			unless command
				loaded_from = Mandar::Core::Config.loaded_from(parent_elem)
				location = "#{loaded_from}:#{elem.line_num}"
				Mandar.die "No such command <#{elem.name}> at #{location}"
			end
			target = command[:target]
			target.send "command_#{command_name}", elem
		end
	end

	register self, :detail
	register self, :notice
	register self, :warning

	def self.command_detail(detail_elem)
		detail_message = detail_elem.attributes["message"]
		Mandar.notice detail_message
	end

	def self.command_notice(notice_elem)
		notice_message = notice_elem.attributes["message"]
		Mandar.notice notice_message
	end

	def self.command_warning(warning_elem)
		warning_message = warning_elem.attributes["message"]
		Mandar.warning warning_message
	end

end
