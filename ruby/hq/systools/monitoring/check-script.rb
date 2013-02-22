module HQ
module SysTools
module Monitoring
class CheckScript

	attr_accessor :args
	attr_accessor :status
	attr_accessor :stdout
	attr_accessor :stderr

	def initialize
		@name = "Unnamed"
		@messages = []
		@critical = false
		@warning = false
		@unknown = false
		@postscript = []
		@stdout = $stdout
		@stderr = $stderr
	end

	def main

		process_args

		begin
			prepare
			perform_checks
		rescue => e
			unknown e.message
			@postscript << e.backtrace
		end

		perform_output

	end

	def prepare
	end

	def perform_output

		if @critical
			@stdout.puts "#{@name} CRITICAL: #{@messages.join ", "}"
			@status = 2

		elsif @warning
			@stdout.puts "#{@name} WARNING: #{@messages.join ", "}"
			@status = 1

		elsif @unknown
			@stdout.puts "#{@name} UNKNOWN: #{@messages.join ", "}"
			@status = 3

		else
			@stdout.puts "#{@name} OK: #{@messages.join ", "}"
			@status = 0
		end

		@postscript.each do |ps|
			@stderr.puts ps
		end

	end

	def message string
		@messages << string
	end

	def critical string
		@messages << string
		@critical = true
	end

	def warning string
		@messages << string
		@warning = true
	end

	def unknown string
		@messages << string
		@unknown = true
	end

end
end
end
end
