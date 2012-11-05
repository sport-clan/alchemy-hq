module Mandar::Deploy::Flag

	FLAG_DIR = "/etc/mandar-flags"

	# main api

	def self.verify_flag_name name

		name.is_a? String \
			or raise "Flag name must be a string"

		name.length > 0 \
			or raise "Flag name must not be empty"

	end

	def self.auto_flag name, &proc

		verify_flag_name name

		push name

		begin
			proc.call
		ensure
			pop name
		end

	end

	def self.clear_flag name, glob = false, &proc

		verify_flag_name name

		if glob
			names = flags.keys.select {
				|flag|
				File.fnmatch name, flag
			}
		else
			names = [ name ]
		end

		if names.any? { |name| check name }
			proc.call
		end

		names.each { |name| clear name }

	end

	def self.set_flag name, value, &proc

		verify_flag_name name

		unless check name, value
			clear name
			proc.call
		end

		set name, value

	end

	def self.check_flag name, &proc

		verify_flag_name name

		if check flag_name
			proc.call
		end

	end

	# called by commands when they perform a change

	def self.auto
		@flag_stack ||= []
		@flag_stack.each do |flag_name|
			set flag_name
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

		flag_glob =
			case clear_flag_elem.attributes["glob"]
				when "yes" then true
				when "no", nil then false
			end

		raise "missing attribute name on <clear-flag>" \
			unless flag_name

		clear_flag flag_name, flag_glob do
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

private

	def self.push name
		@flag_stack ||= []
		@flag_stack.push name
	end

	def self.pop name
		@flag_stack ||= []
		@flag_stack.pop == name or raise "flag name mismatch"
	end

	def self.set name, value = ""

		verify_flag_name name

		# set flag in memory

		flags[name] = value

		# and on disk, unless mock is enabled

		unless $mock
			File.open "#{FLAG_DIR}/#{name}", "w" do |f|
				f.print "#{value}\n"
			end
		end

	end

	def self.clear name

		verify_flag_name name

		# remove the flag from memory

		flags.delete name

		# and on disk, unless mock is enabled

		unless $mock
			FileUtils.remove_entry_secure "#{FLAG_DIR}/#{name}" \
				if File.exists? "#{FLAG_DIR}/#{name}"
		end

	end

	def self.check name, expect = nil

		verify_flag_name name

		# unset flags always return false

		return false \
			unless flags.has_key? name

		# set flags return true if we don't care about the value

		return true \
			if expect == nil

		# otherwise compare the value to the expected

		return flags[name] == expect

	end

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
