class Mandar::Engine::ConfigClient

	def start()

		# check if a recompile is needed
		flag_path = "#{WORK}/.compile-flag"
		recompile = false
		if File.exists? flag_path
			flag_time = File.stat(flag_path).mtime
			Find.find "#{MANDAR}/java", "#{MANDAR}/etc/build.xml" do |path|
				file_time = File.stat(path).mtime
				next unless file_time > flag_time
				recompile = true
				break
			end
		else
			recompile = true
		end

		# shutdown and recompile
		Mandar.debug "shutting down config daemon (if running)"
		if recompile
			begin
				connect
				shutdown if connected
			ensure
				close
			end
			Mandar.notice "recompiling config daemon"
			Mandar::Support::Core.shell "ant -f #{MANDAR}/etc/build.xml compile" or raise "Error"
			FileUtils.mkdir_p File.dirname(flag_path)
			FileUtils.touch flag_path
		end

		# check for already running daemon
		Mandar.debug "connecting to config daemon"
		return if connect

		# start new daemon
		Mandar.notice "starting config daemon"
		Mandar::Support::Core.shell "ant -f #{MANDAR}/etc/build.xml run-daemon"

		unless connect 100
			raise "error"
		end
	end

	def initialize()
		@connected = false
	end

	def connected()
		return @connected
	end

	def connect(tries = 1)
		return if @connected
		Mandar.debug "config client connecting"

		@config_sock = nil
		tries.times do
			sleep 0.1
			begin
				@config_sock = TCPSocket.open "localhost", 3776
				process_response
				break
			rescue Errno::ECONNREFUSED
			end
		end
		@connected = @config_sock ? true : false
		Mandar.debug "config client connect failed" unless @connected
		return @connected
	end

	def close()
		return unless @connected
		begin
			perform "exit"
		ensure
			Mandar.debug "config client closing"
			@config_sock.close
		end
		@connected = false
	end

	def shutdown()
		@connected or raise "error"
		return unless @connected
		begin
			perform "shutdown"
		ensure
			Mandar.debug "config client closing"
			@config_sock.close
		end
		@connected = false
	end

	def set_document name, document
		perform "set-document", :name => name, :document => document
	end

	def compile_xslt path
		perform "compile-xslt", :path => path
	end

	def execute_xslt
		ret = perform "execute-xslt"
		return ret["document"]
	end

	def reset
		perform "reset"
	end

	def perform(command, options = {})
		options = options.clone
		options["command"] = command
		json = JSON.dump options
		sock_send json
		return process_response
	end

	def process_response()
		response_string = sock_receive
		response_json = JSON.parse response_string
		case response_json["result"]
		when "ok"
			Mandar.notice response_json["output"] unless response_json["output"].empty?
			return response_json
			#output = URI.unescape($1.gsub("+", " ")).chomp
		when "error"
			Mandar.error [
				response_json["error"],
				response_json["stack"],
				response_json["output"],
			].join("\n")
			raise "error"
		else
			raise "got invalid response: #{resp}"
		end
	end

	def sock_receive()
		resp = @config_sock.gets.chomp
		Mandar.trace "config client got: #{resp}"
		return resp
	end

	def sock_send(command)
		Mandar.trace "config client sent: #{command}"
		@config_sock.print "#{command}\n"
	end
end
