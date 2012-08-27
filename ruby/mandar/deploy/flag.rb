module Mandar::Deploy::Flag

	FLAG_DIR = "/etc/mandar-flags"

	# main api

	def self.auto_flag name, &proc

		Mandar::Deploy::Flag.push name

		begin
			proc.call
		ensure
			Mandar::Deploy::Flag.pop name
		end

	end

	def self.clear_flag name, &proc

		if Mandar::Deploy::Flag.check name
			proc.call
		end

		Mandar::Deploy::Flag.clear name

	end

	def self.set_flag name, value, &proc

		unless Mandar::Deploy::Flag.check name, value
			Mandar::Deploy::Flag.clear name
			proc.call
		end

		Mandar::Deploy::Flag.set name, value

	end

	def self.check_flag name, &proc

		if Mandar::Deploy::Flag.check flag_name
			proc.call
		end

	end

	# commands

	Mandar::Deploy::Commands.register self, \
		:auto_flag, \
		:clear_flag, \
		:check_flag, \
		:set_flag

	def self.command_auto_flag auto_flag_elem

		flag_name =
			auto_flag_elem.attributes["name"]

		raise "missing attribute name on <auto-flag>" \
			unless flag_name

		auto_flag flag_name do
			Mandar::Deploy::Commands.perform auto_flag_elem
		end

	end

	def self.command_clear_flag clear_flag_elem

		flag_name =
			clear_flag_elem.attributes["name"]

		raise "missing attribute name on <clear-flag>" \
			unless flag_name

		clear_flag flag_name do
			Mandar::Deploy::Commands.perform clear_flag_elem
		end

	end

	def self.command_check_flag check_flag_elem

		flag_name =
			clear_flag_elem.attributes["name"]

		raise "missing attribute name on <check-flag>" \
			unless flag_name

		check_flag flag_name do
			Mandar::Deploy::Commands.perform check_flag_elem
		end

	end

	def self.command_set_flag set_flag_elem

		flag_name = \
			set_flag_elem.attributes["name"]

		flag_value = \
			set_flag_elem.attributes["value"]

		raise "missing attribute name on <check-flag>" unless flag_name

		set_flag flag_name, flag_value do
			Mandar::Deploy::Commands.perform set_flag_elem
		end

	end

	# core flag logic

	def self.push name
		@flag_stack ||= []
		@flag_stack.push name
	end

	def self.pop name
		@flag_stack ||= []
		@flag_stack.pop == name or raise "flag name mismatch"
	end

	def self.auto
		@flag_stack ||= []
		@flag_stack.each do |flag_name|
			set flag_name
		end
	end

	def self.set name, value = ""

		flags[name] = value

		unless $mock
			File.open "#{FLAG_DIR}/#{name}", "w" do |f|
				f.print "#{value}\n"
			end
		end

	end

	def self.clear name

		flags.delete name

		unless $mock
			FileUtils.remove_entry_secure "#{FLAG_DIR}/#{name}" \
				if File.exists? "#{FLAG_DIR}/#{name}"
		end

	end

	def self.check name, expect = nil
		return false unless flags.has_key? name
		return true if expect == nil
		return flags[name] == expect
	end

private

	def self.flags
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
