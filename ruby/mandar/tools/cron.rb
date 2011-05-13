module Mandar::Tools::Cron

	def self.wrap(log = nil)

		unless log
			require "tempfile"
			temp = Tempfile.new("mandar-cron")
			log = temp.path
		end
		begin

			caught_exception = nil
			stdout_saved = $stdout.dup
			stderr_saved = $stderr.dup
			$stdout.reopen log, "a"
			$stderr.reopen log, "a"

			begin
				yield log
			rescue => e
				caught_exception = e
			end
			$stdout.flush
			$stderr.flush

			$stdout.reopen stdout_saved
			$stderr.reopen stderr_saved
			stdout_saved.close
			stderr_saved.close

			if caught_exception
				system "cat #{log} >&2"
				$stderr.puts "Caught #{caught_exception.class}: #{caught_exception.message}"
				$stderr.puts caught_exception.backtrace.join("\n")
			end

		ensure
			temp.unlink if temp
		end

	end

end
