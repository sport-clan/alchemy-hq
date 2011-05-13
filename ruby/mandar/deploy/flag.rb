module Mandar::Deploy::Flag

	FLAG_DIR = "/etc/mandar-flags"

	Mandar::Deploy::Commands.register self, :auto_flag, :clear_flag, :check_flag, :set_flag

	def self.command_auto_flag(auto_flag_elem)

		flag_name = auto_flag_elem.attributes["name"]

		raise "missing attribute name on <auto-flag>" unless flag_name

		Mandar::Deploy::Flag.push flag_name
		begin
			Mandar::Deploy::Commands.perform auto_flag_elem
		ensure
			Mandar::Deploy::Flag.pop flag_name
		end
	end

	def self.command_clear_flag(clear_flag_elem)

		flag_name = clear_flag_elem.attributes["name"]

		raise "missing attribute name on <clear-flag>" unless flag_name

		if Mandar::Deploy::Flag.check flag_name
			Mandar::Deploy::Commands.perform clear_flag_elem
		end

		Mandar::Deploy::Flag.clear flag_name
	end

	def self.command_check_flag(check_flag_elem)

		flag_name = clear_flag_elem.attributes["name"]

		raise "missing attribute name on <check-flag>" unless flag_name

		if Mandar::Deploy::Flag.check flag_name
			Mandar::Deploy::Commands.perform check_flag_elem
		end
	end

	def self.command_set_flag(set_flag_elem)

		flag_name = set_flag_elem.attributes["name"]
		flag_value = set_flag_elem.attributes["value"]

		raise "missing attribute name on <check-flag>" unless flag_name

		unless Mandar::Deploy::Flag.check flag_name, flag_value
			Mandar::Deploy::Flag.clear flag_name
			Mandar::Deploy::Commands.perform set_flag_elem
		end

		Mandar::Deploy::Flag.set flag_name, flag_value
	end

	def self.push(name)
		@flag_stack ||= []
		@flag_stack.push name
	end

	def self.pop(name)
		@flag_stack ||= []
		@flag_stack.pop == name or raise "flag name mismatch"
	end

	def self.auto()
		@flag_stack ||= []
		@flag_stack.each do |flag_name|
			set flag_name
		end
	end

	def self.set(name, value = "")
		flags[name] = value
		unless $mock
			File.open "#{FLAG_DIR}/#{name}", "w" do |f|
				f.print "#{value}\n"
			end
		end
	end

	def self.clear(name)
		flags.delete name
		unless $mock
			FileUtils.remove_entry_secure "#{FLAG_DIR}/#{name}" \
				if File.exists? "#{FLAG_DIR}/#{name}"
		end
	end

	def self.check(name, expect = nil)
		return false unless flags.has_key? name
		return true if expect == nil
		return flags[name] == expect
	end

private

	def self.flags()
		return @flags if @flags
		flags = {}
		FileUtils.mkdir_p FLAG_DIR
		Dir.new("#{FLAG_DIR}").each do |name|
			path = "#{FLAG_DIR}/#{name}"
			next unless File.file? path
			flags[name] = File.read(path).chomp
		end
		return @flags = flags
	end

end
