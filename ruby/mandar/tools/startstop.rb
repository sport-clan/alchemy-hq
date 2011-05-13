#!/usr/bin/ruby

module Mandar::Tools::StartStop

	def self.start(name, pid_file, exec, args)

		# test if already running
		return true if status(name, pid_file, exec)

		# start process
		puts "starting #{name}"
		start_cmd = %W[
			start-stop-daemon
			--start
			--pidfile #{pid_file}
			--exec #{exec}
			--chuid #{USER}
		]
		start_cmd += %W[ -- ] + args
		puts start_cmd.join(" ") if DEBUG
		system start_cmd.join(" ") or return false
	end

	def self.stop(name, pid_file, exec)

		# test if already running
		return true unless status(name, pid_file, exec)

		# stop process
		puts "stopping #{name}"
		stop_cmd = %W[
			start-stop-daemon
			--stop
			--pidfile #{pid_file}
			--name #{File.basename exec}
		]
		stop_cmd << %W[ --quiet ] unless DEBUG
		puts stop_cmd.join(" ") if DEBUG
		system stop_cmd.join(" ") or return false

		# return
		return true
	end

	def self.status(name, pid_file, exec)

		# test if already running
		test_cmd = %W[
			start-stop-daemon
			--stop
			--pidfile #{pid_file}
			--name #{File.basename exec}
			--test
		]
		test_cmd << %W[ --quiet ] unless DEBUG
		puts test_cmd.join(" ") if DEBUG
		system test_cmd.join(" ") or return false

		return true
	end

	def self.auto(op, name, pid_file, exec, args)
		case op
		when "start"
			return start name, pid_file, exec, args
		when "stop"
			return stop name, pid_file, exec
		when "status"
			return status name, pid_file, exec
		else
			raise "Error"
		end
	end

end
