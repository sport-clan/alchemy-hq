module Mandar::Tools::Cron

	def self.wrap log = nil

		is_tty = $stderr.tty?

		if log
			log = String.new log
			log.gsub! /@ts(@|\b)/, Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
			log.gsub! /@pid(@|\b)/, $$.to_s
		else
			require "tempfile"
			temp = Tempfile.new "mandar-cron"
			log = temp.path
		end
		begin

			caught_exception = nil
			stdout_saved = $stdout.dup unless is_tty
			stderr_saved = $stderr.dup unless is_tty
			$stdout.reopen log, "a" unless is_tty
			$stderr.reopen log, "a" unless is_tty

			begin
				yield log
			rescue => e
				caught_exception = e
			end
			$stdout.flush unless is_tty
			$stderr.flush unless is_tty

			$stdout.reopen stdout_saved unless is_tty
			$stderr.reopen stderr_saved unless is_tty
			stdout_saved.close unless is_tty
			stderr_saved.close unless is_tty

			if caught_exception
				system "cat #{log} >&2"
				$stderr.puts "Caught #{caught_exception.class}: #{caught_exception.message}"
				$stderr.puts caught_exception.backtrace.join "\n"
			end

		ensure
			temp.unlink if temp
		end

	end

end
