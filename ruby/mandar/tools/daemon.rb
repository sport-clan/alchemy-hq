module Mandar::Tools::Daemon

	def self.start options, &proc

		# fork
		rd, @wr = IO.pipe
		if child_pid = fork
			@wr.close

			# relay output from child
			while line = rd.gets
				case line
				when /^log (.+)$/
					$stderr.puts $1
				when /^exit (.+)$/
					exit $1.to_i
				else
					raise "Error"
				end
			end

			# exit
			exit 0

		else
			rd.close
			@wr.sync = true

			begin

				# redirect output to log files
				$stdin.close
				$stdout.reopen options[:log_path], "a"
				$stdout.sync = true
				$stderr.reopen options[:log_path], "a"
				$stderr.sync = true

				# output an initial message
				log "Starting pid #{$$}"

				# check for existing pid file
				if File.exists? options[:pid_path]
					existing_pid = File.read(options[:pid_path]).to_i
					if File.directory? "/proc/#{existing_pid}"
						log "Already running as pid #{existing_pid}"
						log "Exiting pid #{$$}"
						detach 1
						exit 1
					end
				end

				# remove pid file at exit
				at_exit do
					log "Exiting pid #{$$}"
					File.unlink options[:pid_path]
				end

				# create pid file
				File.open options[:pid_path], "w" do |f|
					f.puts $$
				end

				# yield
				yield self

			rescue => e

				log "#{e}"

			end
		end
	end

	def self.log message
		now = Time.now.utc.strftime "%Y-%m-%dT%H:%M:%SZ"
		message.chomp.split("\n").each do |line|
			$stderr.puts "#{now} #{line}"
			@wr.puts "log #{now} #{line}" if @wr
		end
	end

	def self.detach status = 0
		@wr.puts "exit #{status}"
		@wr.close
		@wr = nil
	end

	def self.stop options

		# check for existing pid file
		unless File.exists? options[:pid_path]
			log "No PID file found"
			return
		end
		existing_pid = File.read(options[:pid_path]).to_i

		# check for process
		unless File.directory? "/proc/#{existing_pid}"
			log "No process found with PID #{existing_pid}"
			log "Removing stale PID file"
			File.unlink options[:pid_path]
			return
		end

		# kill process and wait for it to die
		log "Killing PID #{existing_pid}"
		Process.kill "TERM", existing_pid
		sleep 0.1 while File.directory? "/proc/#{existing_pid}"

	end

	def self.auto opts, &proc
		case opts[:action]

		when :start
			self.start opts, &proc

		when :stop
			self.stop opts, &proc

		when :restart
			self.stop opts, &proc
			self.start opts, &proc

		else
			raise "Don't recognise action: #{opts[:action]}"

		end
	end

end
