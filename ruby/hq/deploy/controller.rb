require "hq/dir"
require "hq/tools/escape"

module HQ
module Deploy
class Controller

	include HQ::Tools::Escape

	attr_accessor :master

	def config() master.config end
	def config_dir() master.config_dir end
	def deploy_dir() master.deploy_dir end
	def em_wrapper() master.em_wrapper end
	def engine() master.engine end
	def logger() master.logger end
	def remote_command() master.remote_command end
	def work_dir() master.work_dir end

	def send_to host_name, &return_proc

		rsync_proc = nil
		bundle_install_proc = nil

		host_elem =
			engine.abstract["deploy-host"] \
				.find_first("deploy-host [@name = '#{host_name}']")

		host_elem \
			or raise "No such host #{host_name}"

		host_hostname =
			host_elem.attributes["hostname"]

		host_hostname \
			or raise "No hostname for host #{host_name}"

		connect_proc = proc do

			connect_to host_name do
				|success|

				if success
					rsync_proc.call
				else
					return_proc.call false
				end

			end

		end


		rsync_proc = proc do

			message =
				"sending to #{host_name}"

			logger.debug message

			projects_dir =
				File.expand_path "..", config_dir

			rsh_args = [
				"ssh",
				"-S", "#{work_dir}/ssh/#{host_name}.sock",
				"-o", "BatchMode=yes",
				"-o", "ConnectTimeout=10",
			]

			rsh_cmd =
				esc_shell rsh_args

			rsync_args = [

				"rsync",

				"--times",
				"--delete",
				"--executability",
				"--links",
				"--perms",
				"--recursive",
				"--rsh=#{rsh_cmd}",
				"--timeout=30",

			]

			host_elem.find("include").each do |include_elem|

				include_name =
					include_elem.attributes["name"]

				rsync_args += [
					"--include=/#{deploy_dir}/.work/deploy/#{include_name}",
				]

			end

			rsync_args += [

				"--include=/alchemy-hq",
				"--include=/alchemy-hq/alchemy-hq.gemspec",
				"--include=/alchemy-hq/bin",
				"--include=/alchemy-hq/etc",
				"--exclude=/alchemy-hq/etc/build.properties",
				"--include=/alchemy-hq/ruby",
				"--exclude=/alchemy-hq/*",
				"--include=/alchemy-hq",

				"--include=/devbox/Gemfile",
				"--include=/devbox/Gemfile.lock",
				"--include=/devbox/devbox.gemspec",
				"--include=/devbox/lib",
				"--exclude=/devbox/*",
				"--include=/devbox",

				"--include=/#{deploy_dir}/.dependencies",

				"--exclude=/#{deploy_dir}/.work/deploy/*/*",
				"--include=/#{deploy_dir}/.work/deploy/*",
				"--include=/#{deploy_dir}/.work/deploy",
				"--exclude=/#{deploy_dir}/.work/*",
				"--include=/#{deploy_dir}/.work",

				"--include=/#{deploy_dir}/Gemfile",
				"--include=/#{deploy_dir}/Gemfile.lock",
				"--include=/#{deploy_dir}/*.gemspec",

				"--exclude=/#{deploy_dir}/vendor/cache/archive-tar-minitar-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/builder-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/childprocess-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/cucumber-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/diff-lcs-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/erubis-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/gherkin-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/i18n-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/log4r-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/net-scp-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/net-ssh-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/rspec-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/ruby-graphviz-*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/vagrant-*.gem",
				"--include=/#{deploy_dir}/vendor/cache/*.gem",
				"--exclude=/#{deploy_dir}/vendor/cache/*",
				"--include=/#{deploy_dir}/vendor/cache",
				"--exclude=/#{deploy_dir}/vendor/*",
				"--include=/#{deploy_dir}/vendor",

				"--include=/#{deploy_dir}/bin",
				"--include=/#{deploy_dir}/ruby",
				"--include=/#{deploy_dir}/scripts",

				"--exclude=/#{deploy_dir}/*",
				"--include=/#{deploy_dir}",

				"--exclude=/*",

				"--exclude=.*",

				"#{projects_dir}/",
				"root@#{host_hostname}:/",

			]

			rsync_cmd =
				"exec #{esc_shell rsync_args} </dev/null"

			logger.debug "executing #{rsync_cmd}"

			bash_args = [
				"bash",
				"-c",
				rsync_cmd,
			]

			EventMachine.system "bash", "-c", rsync_cmd do
				|output, status|

				if status.exitstatus == 0
					bundle_install_proc.call
				else
					puts rsync_cmd, output
					return_proc.call false
				end

			end

		end

		bundle_install_proc = proc do

			# run bundle install

			ssh_args = [
				"ssh",
				"-q",
				"-T",
				"-A",
				"-S", "#{work_dir}/ssh/#{host_name}.sock",
				"-o", "BatchMode=yes",
				"root@#{host_hostname}",
				[
					"chmod 0755 /",
					"cd /zattikka-hq",
					"mkdir -p .override",
					"ln -sfd /zattikka-hq/alchemy-hq .override/alchemy-hq",
					[
						"bundle install",
						"--path .gems",
						"--binstubs .stubs",
						"--local",
						"--without rrd development",
						"--quiet",
					].join(" "),
				].join("; "),
			]

			ssh_cmd =
				"exec #{esc_shell ssh_args}"

			logger.debug "executing #{ssh_cmd}"

			EventMachine.system "bash", "-c", ssh_cmd do
				|output, status|

				if status.exitstatus == 0
					return_proc.call true
				else
					puts ssh_cmd, output
					return_proc.call false
				end

			end

		end

		connect_proc.call

	end

	def run_on_host host_name, cmd, redirect = ""

		host_elem =
			engine.abstract["deploy-host"] \
				.find_first("deploy-host [@name = '#{host_name}']")

		host_hostname = host_elem.attributes["hostname"]
		ssh_args = %W[
			ssh -q -T -A
			-S #{WORK}/ssh/#{host_name}.sock
			-o BatchMode=yes
			root@#{host_hostname}
			#{esc_shell cmd}
		]
		ssh_cmd = "#{esc_shell ssh_args} </dev/null #{redirect}"
		logger.debug "executing #{ssh_cmd}"
		tmp = system ssh_cmd
		return tmp

	end

	def run_self_locally args, &return_proc

		hq_args = [
			"#{config_dir}/.stubs/#{remote_command}",
			"--log", "trace:raw",
			*args,
		]

		hq_cmd =
			esc_shell hq_args

		# execute it

		logger.debug "executing #{hq_cmd}"

		deploy_handler =
			EventMachine.popen \
				hq_cmd,
				DeployHandler

		deploy_handler.logger = logger

		deploy_handler.on_success do
			return_proc.call true
		end

		deploy_handler.on_error do
			return_proc.call false
		end

	end

	def run_self_on_host host_name, args, &return_proc

		# build command

		remote_args = [
			"/#{deploy_dir}/.stubs/#{remote_command}",
			"--log", "trace:raw",
			*args,
		]

		remote_cmd =
			esc_shell remote_args

		host_elem =
			engine.abstract["deploy-host"] \
				.find_first("deploy-host [@name = #{esc_xp host_name}]")

		host_hostname =
			host_elem["hostname"]

		ssh_args = [
			"ssh",
			"-q",
			"-T",
			"-A",
			"-S", "#{work_dir}/ssh/#{host_name}.sock",
			"-o", "BatchMode=yes",
			"root@#{host_hostname}",
			remote_cmd,
		]

		ssh_cmd =
			esc_shell ssh_args

		# execute it

		logger.debug "executing #{ssh_cmd}"

		deploy_handler =
			EventMachine.popen \
				ssh_cmd,
				DeployHandler

		deploy_handler.logger = logger

		deploy_handler.on_success do
			return_proc.call true
		end

		deploy_handler.on_error do
			return_proc.call false
		end

	end

	def deploy hosts

		# number of consecutive operations

		max_threads =
			(config.find_first("deploy")["threads"] || 10).to_i

		if max_threads == 1

			logger.notice \
				"performing deployments in series"

		else

			logger.notice \
				"performing deployments in parallel, #{max_threads} threads"

		end

		# track what we are doing

		remaining_hosts = hosts.clone
		current_hosts = []

		# error is set to true if any part fails in any thread

		success_count = 0
		error_count = 0

		em_wrapper.slow do
			|return_proc|

			returned = false

			next_host_proc =
				proc do
				|error|

				if current_hosts.size < max_threads \
						&& ! remaining_hosts.empty?

					next_host =
						remaining_hosts.shift

					current_hosts << next_host

					deploy_host next_host do
						|success|

						if success
							success_count += 1
						else
							error_count += 1
						end

						current_hosts.delete next_host

						EventMachine.next_tick do
							next_host_proc.call
						end

					end

					EventMachine.next_tick do
						next_host_proc.call
					end

				elsif remaining_hosts.empty? \
					&& current_hosts.empty? \
					&& ! returned

					returned = true

					EventMachine.next_tick do
						return_proc.call
					end

				end

			end

			EventMachine.next_tick do
				next_host_proc.call false
			end

		end

		# check for error and output appropriate message

		if error_count > 0
			logger.die "errors detected during one or more deployments"
		else
			logger.notice "all deployments completed successfully"
		end

	end

	def deploy_host host, &return_proc

		start_proc = nil
		send_to_host_proc = nil
		deploy_on_host_proc = nil
		run_local_proc = nil

		start_proc =
			proc do

			if host == "local"

				EventMachine.next_tick do
					run_local_proc.call
				end

			else

				EventMachine.next_tick do
					send_to_host_proc.call
				end

			end

		end

		send_to_host_proc =
			proc do

			send_to host do
				|success|

				if success
					deploy_on_host_proc.call
				else
					puts "send to host #{host} failed"
					return_proc.call false
				end

			end

		end

		deploy_on_host_proc =
			proc do

			args = [
				"server-deploy",
				host,
				"host/#{host}/deploy.xml",
			]

			args += [
				"--mock",
			] if $mock

			run_self_on_host host, args do
				|success|

				if success
					return_proc.call true
				else
					puts "deploy on #{host} failed"
					return_proc.call false
				end

			end

		end

		run_local_proc =
			proc do

			args = [
				"local-deploy",
				"host/local/deploy.xml",
			]

			args += [
				"--mock",
			] if $mock

			run_self_locally args do
				|success|

				if success
					return_proc.call true
				else
					puts "deploy local failed"
					return_proc.call false
				end

			end

		end

		start_proc.call

	end

	def run_command hosts, command

		logger.notice "running command on hosts"

		hosts.each do |host|
			logger.notice "running on #{host}"
			run_self_on_host host, [ "server-run", command ]
		end

	end

	module DeployHandler

		attr_accessor :logger

		def post_init
			@buf = ""
		end

		def receive_data data

			@buf += data
			last_pos = 0

			while next_pos = @buf.index("\n", last_pos)
				line = @buf[last_pos...next_pos]
				process_line line
				last_pos = next_pos + 1
			end

			@buf = @buf[last_pos..-1]

		end

		def process_line line

			begin

				data =
					MultiJson.load line

			rescue => e
				$stderr.print "#{line}\n"
				return
			end

			begin

				data["content"].each do
					|item|

					logger.output \
						item,
						data["mode"].to_sym

				end

			rescue => e
				puts "Error outputting log message:"
				require "pp"
				pp data
			end

		end

		def on_success &proc
			@success_proc = proc
		end

		def on_error &proc
			@error_proc = proc
		end

		def unbind *args
			if get_status == 0
				@success_proc.call
			else
				@error_proc.call
			end
		end

	end

	def connect_to host_name, &return_proc

		host_elem =
			engine.abstract["deploy-host"] \
				.find_first("deploy-host [@name = '#{host_name}']")

		host_elem \
			or raise "No such host: #{host_name}"

		host_hostname =
			host_elem.attributes["hostname"]

		host_hostname \
			or raise "No hostname for host #{host_name}"

		host_ip =
			host_elem.attributes["ip"]

		host_ip \
			or raise "No IP address for host #{host_name}"

		host_ssh_host_key =
			host_elem.attributes["ssh-host-key"]

		host_ssh_host_key \
			or raise "No host key for host #{host_name}"

		host_ssh_key_name =
			host_elem.attributes["ssh-key-name"]

		host_ssh_key_name \
			or raise "No key name for host #{host_name}"

		FileUtils.mkdir_p "#{work_dir}/ssh"
		run_path = "#{work_dir}/ssh/#{host_name}"
		socket_path = "#{run_path}.sock"
		pid_path = "#{run_path}.pid"

		# setup ssh host keys

		system "ssh-keygen -R #{host_hostname} 2>/dev/null"
		system "ssh-keygen -R #{host_ip} 2>/dev/null"
		FileUtils.mkdir_p "#{ENV["HOME"]}/.ssh"
		File.open("#{ENV["HOME"]}/.ssh/known_hosts", "a") do |f|
			f.print "#{host_hostname} #{host_ssh_host_key}\n"
			f.print "#{host_ip} #{host_ssh_host_key}\n"
		end

		ssh_key_elem =
			engine.abstract["mandar-ssh-key"] \
				.find_first("mandar-ssh-key [@name = #{esc_xp host_ssh_key_name}]")

		ssh_key =
			ssh_key_elem.find_first("private").content

		if File.exists? socket_path
			return_proc.call true
			return
		end

		logger.notice "connecting to #{host_name}"

		# write ssh key file

		Tempfile.open "mandar-ssh-key-" do |ssh_key_file|

			ssh_key_file.puts ssh_key
			ssh_key_file.flush

			identity_path =
				$ssh_identity || ssh_key_file.path

			# and execute ssh process

			ssh_args = [
				"#{HQ::DIR}/etc/ssh-wrapper",
				run_path,
				"ssh", "-MNqa",
				"root@#{host_hostname}",
				"-S", socket_path,
				"-i", identity_path,
				"-o", "ServerAliveInterval=10",
				"-o", "ServerAliveCountMax=3",
				"-o", "ConnectTimeout=10",
				"-o", "BatchMode=yes",
			]

			ssh_cmd = "exec #{esc_shell ssh_args} </dev/null"

			logger.debug "executing #{ssh_cmd}"

			EventMachine.system "bash", "-c", ssh_cmd do
				|output, status|

				if status.exitstatus == 0
					return_proc.call true
				else
					puts ssh_cmd, output
					return_proc.call false
				end

			end

		end

	end

	def disconnect_all
		if File.directory? "#{work_dir}/ssh"
			Dir.new("#{work_dir}/ssh").each do |filename|
				next unless filename =~ /^(.+)\.pid$/
				host = $1
				logger.notice "disconnecting from #{host}"
				pid = File.read("#{work_dir}/ssh/#{host}.pid").to_i
				Process.kill 15, pid
			end
		end
	end

end
end
end
