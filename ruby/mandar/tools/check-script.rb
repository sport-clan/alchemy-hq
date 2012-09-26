class Mandar::Tools::CheckScript

	attr_accessor :args
	attr_accessor :status

	def initialize
		@name = "Unnamed"
		@messages = []
		@critical = false
		@warning = false
		@unknown = false
		@postscript = []
	end

	def main

		process_args

		begin
			perform_checks
		rescue => e
			unknown e.message
			@postscript << e.backtrace
		end

		perform_output

	end

	def perform_output

		if @critical
			puts "#{@name} CRITICAL: #{@messages.join ", "}"
			@status = 2

		elsif @warning
			puts "#{@name} WARNING: #{@messages.join ", "}"
			@status = 1

		elsif @unknown
			puts "#{@name} UNKNOWN: #{@messages.join ", "}"
			@status = 3

		else
			puts "#{@name} OK: #{@messages.join ", "}"
			@status = 0
		end

		@postscript.each do |ps|
			$stderr.puts ps
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
