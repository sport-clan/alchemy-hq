module Mandar::Grapher::Daemon

	class DebugSink
		def submit(name, data)
			puts "----- #{name}"
			pp data
		end
	end

	def self.test *graphers
		@sink = DebugSink.new
		@graphers = graphers
		if @graphers.empty?
			@graphers = [
				DiskSpaceGrapher.new("disk"),
				CpuGrapher.new("cpu"),
				IfaceGrapher.new("iface", "wlan0"),
				LoadGrapher.new("load"),
				MemoryGrapher.new("memory"),
			]
		end
		@log_file = $stdout
		loop
	end

	class DiskSpaceGrapher

		def initialize(name, path)
			require "sys/filesystem"
			@name = name
			@path = path
		end

		def self.from_elem(elem)
			return new elem.attributes["name"], elem.attributes["path"]
		end

		def run(sink)
			stat = Sys::Filesystem.stat @path
			sink.submit @name, [
				stat.block_size * (stat.blocks - stat.blocks_free),
				stat.block_size * stat.blocks_available,
				stat.block_size * (stat.blocks_free - stat.blocks_available),
			]
		end
	end

	class CpuGrapher

		COL_COUNT = 10

		def initialize(name)
			@name = name
		end

		def self.from_elem(elem)
			return new elem.attributes["name"]
		end

		def run(sink)
			@current = read
			@current_total = @current.inject(0) { |a, b| a + b }

			if @last
				elapsed = @current_total - @last_total
				data = (0...COL_COUNT).map { |i| (@current[i] - @last[i]).to_f / elapsed }
				sink.submit @name, data
			end

			@last = @current
			@last_total = @current_total
		end

		def read()
			lines = File.new("/proc/stat").to_a.map { |line| line.chomp }
			cpu = lines[0].split(/\s+/)
			return (0...COL_COUNT).map { |i| cpu[i + 1].to_i }
		end

	end

	class DiskIoGrapher

		# columns, according to iostats.txt in the linux kernel. diff means we
		# are interested in the change over time, value means we just use
		# whatever the latest value is

		COLS = [
			[ :reads_completed, :diff ],
			[ :reads_merged, :diff ],
			[ :sectors_read, :diff ],
			[ :millis_spent_reading, :diff ],
			[ :writes_completed, :diff ],
			[ :writes_merged, :diff ],
			[ :sectors_written, :diff ],
			[ :millis_spent_writing, :diff ],
			[ :ios_in_progress, :value ],
			[ :millis_doing_io, :diff ],
			[ :weighted_millis_doing_io, :diff ],
		]

		def initialize name, disk
			@name = name
			@disk = disk
		end

		def self.from_elem elem
			return new \
				elem.attributes["name"],
				elem.attributes["disk"]
		end

		def run sink

			# get current data and time

			@current = read
			@current_time = Time.now

			# if we have data from a previous run

			if @last

				# work out elapsed time

				@elapsed =
					@current_time - @last_time

				# and submit if it was close to a second

				if (@elapsed - 1.0).abs < 0.1
					submit sink
				end

			end

			# store current data for next round

			@last = @current
			@last_time = @current_time

		end

		def submit sink

			# generate data by iterating columns

			data = (0...(COLS.size)).map do |i|

				# work out the raw value using the specified method

				temp = case COLS[i][1]

					when :diff
						(@current[i] - @last[i]).to_f * @elapsed

					when :value
						@current[i]

				end

			end

			# submit the data to the daemon

			sink.submit @name, data

		end

		# return an array with the current totals for each column

		def read

			# initialise an array with zeroes

			ret =
				(0...(COLS.size)).map { 0 }

			# iterate lines from the diskstats file

			File.new("/proc/diskstats").each \
				do |line|

					# split columns

					cols =
						line.strip.split /\s+/

					# ignore irrelevant lines

					next \
						unless @disk == "all" \
							|| cols[2] == @disk

					# add this lines data to the totals

					(0...(COLS.size)).each do |i|

						ret[i] +=
							cols[i + 3].to_i

					end

				end

			# and return

			return ret

		end

	end

	class IfaceGrapher

		COL_COUNT = 16

		def initialize(name, iface)
			@name = name
			@iface = iface
		end

		def self.from_elem(elem)
			return new elem.attributes["name"], elem.attributes["iface"]
		end

		def multi_split(string, *patterns)
			return patterns.empty? ? string : string.split(patterns.shift).map { |part| multi_split(part, *patterns) }
		end

		def run(sink)
			@current = read
			@current_time = Time.now

			if @current && @last
				elapsed = @current_time - @last_time
				if (elapsed - 1.0).abs < 0.1
					data = (0...COL_COUNT).map do |i|
						change = @current[i] - @last[i]
						change += 4294967296 if change < 0
						point = change / elapsed
					end
					sink.submit @name, data
				end
			end

			@last = @current
			@last_time = @current_time
		end

		def read()
			lines = File.new("/proc/net/dev").to_a
			multi_split(lines[0], "|", " ") == [
				%W[ Inter- ],
				%W[ Receive ],
				%W[ Transmit ],
			] or raise "Invalid format /proc/net/dev"
			multi_split(lines[1], "|", " ") == [
				%W[ face ],
				%W[ bytes packets errs drop fifo frame compressed multicast ],
				%W[ bytes packets errs drop fifo colls carrier compressed ],
			] or raise "Invalid format /proc/net/dev"
			lines[2..-1].each do |line|
				left, right = multi_split line, ":", " "
				next unless left[0] == @iface
				return (0...COL_COUNT).map { |i| right[i].to_i }
			end
			return nil
		end

	end

	class LoadGrapher

		def initialize(name)
			@name = name
		end

		def self.from_elem(elem)
			return new elem.attributes["name"]
		end

		def run(sink)
			line = File.new("/proc/loadavg").to_a[0].split
			sink.submit @name, [
				line[0].to_f,
				line[1].to_f,
				line[2].to_f,
			]
		end

	end

	class MemoryGrapher

		def initialize(name)
			@name = name
		end

		def self.from_elem(elem)
			return new elem.attributes["name"]
		end

		def run(sink)
			data = {}
			line = File.new("/proc/meminfo").each do |line|
				next unless line =~ /^([^:]+):\s+(\d+) kB$/
				data[$1] = $2.to_i
			end
			sink.submit @name, [
				data["MemTotal"] - data["MemFree"] - data["Buffers"] - data["Cached"],
				data["Buffers"],
				data["Cached"],
				data["MemFree"],
				data["SwapTotal"] - data["SwapFree"] - data["SwapCached"],
				data["SwapCached"],
				data["SwapFree"],
			]
		end

	end

	def self.log(message)
		@log_file.puts "#{Time.now}: #{message}"
		@log_file.flush
	end

	def self.init_log()
		@log_file = File.open @log_path, "a"
		log "starting"
	end

	def self.create_graphers()
		@graphers = []

		@grapher_config_elem.find("*").each do |elem|
			case elem.name

			when "grapher-daemon-diskspace"
				@graphers << DiskSpaceGrapher.from_elem(elem)

			when "grapher-daemon-cpu"
				@graphers << CpuGrapher.from_elem(elem)

			when "grapher-daemon-iface"
				@graphers << IfaceGrapher.from_elem(elem)

			when "grapher-daemon-load"
				@graphers << LoadGrapher.from_elem(elem)

			when "grapher-daemon-memory"
				@graphers << MemoryGrapher.from_elem(elem)

			when "grapher-daemon-diskio"
				@graphers << DiskIoGrapher.from_elem(elem)

			else
				raise "Unexpected <#{elem.name}> element"

			end
		end
	end

	def self.loop()
		time_next = Time.now
		wait = 1
		margin = 0.1
		while true do
			@graphers.each do |grapher|
				begin
					grapher.run @sink
				rescue => e
					log "got error #{e.message}"
					log e.inspect
					log e.backtrace.join("\n")
				end
			end
			time_next += wait
			time_now = Time.now
			if (time_next - time_now - wait).abs > margin
				log "resyncing rather than waiting #{time_next - time_now}"
				time_next = time_now + wait
			end
			sleep time_next - time_now
		end
	end

	#def self.run(config_path)
	#	setup config_path
	#	run
	#end

	def self.process_args(args)

		unless args.size == 1
			puts "Syntax: #{File.basename $0} CONFIG-FILE"
			exit 1
		end
		@config_path = args[0]

		unless File.exists? @config_path
			puts "Config file doesn't exist: #{@config_path}"
			exit 1
		end
	end

	def self.read_config()

		grapher_config_doc = XML::Document.file @config_path
		@grapher_config_elem = grapher_config_doc.root

		@daemon = @grapher_config_elem.attributes["daemon"]
		@log_path = @grapher_config_elem.attributes["log-file"]
		@pid_path = @grapher_config_elem.attributes["pid-file"]
	end

	def self.create_pid

		# check for existing
		if File.exists?(@pid_path) \
				&& (other_pid = File.read(@pid_path).chomp) != $$.to_s \
				&& File.directory?("/proc/#{other_pid}")
			$stderr.puts "Already running as #{other_pid}"
			exit 1
		end

		# create and arrange to delete pid file
		File.open(@pid_path, "w") { |f| f.puts $$ }
		at_exit { File.delete(@pid_path) if File.exists?(@pid_path) }
	end

	def self.start(args)

		# process command line
		process_args args

		# read config file
		read_config

		# open log file
		init_log

		# setup
		create_graphers

		# use self as sink
		@sink = self

		# fork with pipe to signal readiness
		rd, wr = IO.pipe
		fork do
			rd.close

			# create pid file
			create_pid

			# signal parent that we are ok
			wr.close

			# close stdout, etc
			$stdin.close
			$stdout.close
			$stderr.close
			begin

				# main loop
				loop

			rescue => e

				log "caught exception: #{e.message}"
				log "shutting down"

			end

		end
		wr.close

		# wait for child and exit
		rd.gets
	end

	def self.submit(name, data)
		Mandar::Support::RRD.update(name, {
			:daemon => @daemon,
			:data => data,
		})
	end

end
