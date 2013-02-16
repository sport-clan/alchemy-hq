module Mandar::Master

	def self.connect host_name

		abstract =
			Mandar::Core::Config.abstract

		host_elem =
			abstract["deploy-host"] \
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

		FileUtils.mkdir_p "#{WORK}/ssh"
		run_path = "#{WORK}/ssh/#{host_name}"
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
			abstract["mandar-ssh-key"] \
				.find_first("mandar-ssh-key [@name = '#{host_ssh_key_name}']")

		ssh_key =
			ssh_key_elem.find_first("private").content

		unless File.exists? socket_path

			Mandar.notice "connecting to #{host_name}"

			# write ssh key file

			Tempfile.open "mandar-ssh-key-" do |ssh_key_file|

				ssh_key_file.puts ssh_key
				ssh_key_file.flush

				identity_path =
					$ssh_identity || ssh_key_file.path

				# and execute ssh process

				ssh_args = %W[
					#{MANDAR}/etc/ssh-wrapper
					#{run_path}
					ssh -MNqa
					root@#{host_hostname}
					-S #{socket_path}
					-i #{identity_path}
					-o ServerAliveInterval=10
					-o ServerAliveCountMax=3
					-o ConnectTimeout=10
					-o BatchMode=yes
				]

				ssh_cmd = "#{Mandar.shell_quote ssh_args} </dev/null"

				Mandar.debug "executing #{ssh_cmd}"

				system ssh_cmd \
					or raise "Error #{$?.exitstatus} executing #{ssh_cmd}"

			end
		end
	end

	def self.disconnect_all
		if File.directory? "#{WORK}/ssh"
			Dir.new("#{WORK}/ssh").each do |filename|
				next unless filename =~ /^(.+)\.pid$/
				host = $1
				Mandar.notice "disconnecting from #{host}"
				pid = File.read("#{WORK}/ssh/#{host}.pid").to_i
				Process.kill 15, pid
			end
		end
	end

	def self.fix_perms

		Mandar.debug "fixing permissions"

		Mandar.time "fixing permissions" do

			# everything should only be owner writable but world readable
			system Mandar.shell_quote %W[
				chmod --recursive u=rwX,og=rX #{CONFIG}
			] or raise "Error"

			# with the exception of .work which is only owner readable
			system Mandar.shell_quote %W[
				chmod --recursive u=rwX,og= #{CONFIG}/.work
			]

		end

		Mandar.debug "copying alchemy-hq"

		Mandar.time "copying alchemy-hq" do

			ahq_spec =
				Gem::Specification.find_by_name "alchemy-hq"

			rsync_args = [

				"rsync",

				"--times",
				"--copy-links",
				"--delete",
				"--executability",
				"--perms",
				"--recursive",

				"#{ahq_spec.gem_dir}/",
				"#{CONFIG}/alchemy-hq/",

			]

			rsync_cmd =
				Mandar.shell_quote rsync_args

			Mandar.debug "executing #{rsync_cmd}"

			system rsync_cmd \
				or raise "Error #{$?.exitstatus} executing #{rsync_cmd}"

		end

	end

	def self.send_to host_name

		connect host_name

		message =
			"sending to #{host_name}"

		Mandar.debug message

		Mandar.time message do

			abstract =
				Mandar::Core::Config.abstract

			host_elem =
				abstract["deploy-host"] \
					.find_first("deploy-host [@name = '#{host_name}']")

			host_elem \
				or raise "No such host #{host_name}"

			host_hostname =
				host_elem.attributes["hostname"]

			host_hostname \
				or raise "No hostname for host #{host_name}"

			rsh_cmd = Mandar.shell_quote %W[
				ssh
				-S #{WORK}/ssh/#{host_name}.sock
				-o BatchMode=yes
				-o ConnectTimeout=10
			]

			rsync_args = %W[

				rsync

				--times
				--copy-links
				--delete
				--delete-excluded
				--executability
				--perms
				--recursive
				--rsh=#{rsh_cmd}
				--timeout=30

			]

			host_elem.find("include").each do |include_elem|

				include_name =
					include_elem.attributes["name"]

				rsync_args += %W[
					--include=/.work/deploy/#{include_name}
				]

			end

			rsync_args += %W[

				--exclude=/.work/deploy/*/*
				--include=/.work/deploy/*
				--include=/.work/deploy
				--exclude=/.work/*
				--include=/.work

				--include=/alchemy-hq
				--include=/alchemy-hq/bin
				--include=/alchemy-hq/etc
				--exclude=/alchemy-hq/etc/build.properties
				--include=/alchemy-hq/ruby
				--exclude=/alchemy-hq/*

				--include=/bin

				--include=/ruby

				--include=/scripts

				--include=/#{File.basename $0}

				--exclude=/*

				--exclude=.*

				#{CONFIG}/
				root@#{host_hostname}:/#{Mandar.deploy_dir}/

			]

			rsync_cmd = "#{Mandar.shell_quote rsync_args} </dev/null"

			Mandar.debug "executing #{rsync_cmd}"

			system rsync_cmd \
				or raise "Error #{$?.exitstatus} executing #{rsync_cmd}"

		end

	end

	def self.run_on_host host_name, cmd, redirect = ""

		abstract = Mandar::Core::Config.abstract

		host_elem =
			abstract["deploy-host"] \
				.find_first("deploy-host [@name = '#{host_name}']")

		host_hostname = host_elem.attributes["hostname"]
		ssh_args = %W[
			ssh -q -T -A
			-S #{WORK}/ssh/#{host_name}.sock
			-o BatchMode=yes
			root@#{host_hostname}
			#{Mandar.shell_quote cmd}
		]
		ssh_cmd = "#{Mandar.shell_quote ssh_args} </dev/null #{redirect}"
		Mandar.debug "executing #{ssh_cmd}"
		tmp = system ssh_cmd
		return tmp

	end

	def self.run_self_on_host host_name, args

		# build command

		remote_args = [
			"/#{Mandar.deploy_dir}/#{Mandar.remote_command}",
			"--log", "trace:raw",
			*args,
		]

		remote_cmd =
			Mandar.shell_quote remote_args

		abstract =
			Mandar::Core::Config.abstract

		host_elem =
			abstract["deploy-host"] \
				.find_first("deploy-host [@name = '#{host_name}']")

		host_hostname =
			host_elem["hostname"]

		ssh_args = [
			"ssh",
			"-q",
			"-T",
			"-A",
			"-S", "#{WORK}/ssh/#{host_name}.sock",
			"-o", "BatchMode=yes",
			"root@#{host_hostname}",
			remote_cmd,
		]

		ssh_cmd =
			Mandar.shell_quote ssh_args

		# execute it

		Mandar.debug "executing #{ssh_cmd}"

		pipe_read, pipe_write =
			IO.pipe

		pid = fork do

			pipe_read.close

			$stdin.reopen "/dev/null", "r"

			$stdout.reopen pipe_write
			$stderr.reopen pipe_write

			exec *ssh_args

		end

		pipe_write.close

		# process output

		while line = pipe_read.gets

			begin

				data =
					JSON.parse line

			rescue => e
				puts "INVALID DATA: #{line.strip} (#{e.message})"
				next
			end

			begin

				data["content"].each do
					|item|

					Mandar.logger.output \
						item,
						data["mode"].to_sym

				end

			rescue => e
				puts "Error outputting log message:"
				pp data
			end

		end

		# check result and return

		Process.wait pid

		return $?.exitstatus == 0

	end

	def self.deploy hosts
		if $series || hosts.size <= 1
			deploy_series hosts
		else
			deploy_parallel hosts
		end
	end

	def self.deploy_series hosts

		Mandar.notice "performing deployments in series"

		# fix perms first

		fix_perms

		# deploy per host

		error = false

		hosts.each do
			|host|

			Mandar.notice "deploy #{host}"

			begin

				if host == "local"

					HQ::Deploy::Slave.go \
						"host/local/deploy.xml"

				else

					Mandar::Master.send_to host

					args = [
						"server-deploy",
						host,
						"host/#{host}/deploy.xml",
					]

					unless Mandar::Master.run_self_on_host host, args
						Mandar.error "deploy #{host} failed"
						error = true
					end

				end

			rescue => e

				Mandar.error "deploy #{host} failed: #{e.message}"
				Mandar.detail "#{e.to_s}\n#{e.backtrace.join("\n")}"

				error = true

				break

			end

		end

		if error
			Mandar.error "errors detected during one or more deployments"
		else
			Mandar.notice "all deployments completed successfully"
		end
	end

	def self.deploy_parallel hosts

		# fix perms first
		fix_perms

		# queue is used to enforce maximum threads as configured

		max_threads =
			(Mandar::Core::Config.mandar.attributes["threads"] || 10).to_i

		Mandar.notice \
			"performing deployments in parallel, #{max_threads} threads"

		queue = SizedQueue.new max_threads

		# lock is used for output to stop things clobbering each other

		lock = Mutex.new

		# threads are collected so they can be waited on

		threads = []

		# error is set to true if any part fails in any thread

		error = false

		# deploy per host

		hosts.each do |host|

			queue.push :token

			threads << Thread.new do

				begin
					if host == "local"

						HQ::Deploy::Slave.go \
							"host/local/deploy.xml"

					else

						Mandar::Master.send_to host

						args = [
							"server-deploy",
							host,
							"host/#{host}/deploy.xml",
						]

						success =
							Mandar::Master.run_self_on_host \
								host,
								args

						unless success
							Mandar.error "deploy #{host} failed"
							error = true
						end

					end

				rescue => e

					lock.synchronize do
						Mandar.error "deploy #{host} failed: #{e.message}"
						Mandar.detail "#{e.to_s}\n#{e.backtrace.join("\n")}"
						error = true
					end

				ensure
					queue.pop
				end

			end

		end

		# wait for all threads to complete

		threads.each { |thread| thread.join }

		# check for error and output appropriate message

		if error
			Mandar.die "errors detected during one or more deployments"
		else
			Mandar.notice "all deployments completed successfully"
		end

	end

	def self.run_command hosts, command

		Mandar.notice "running command on hosts"

		hosts.each do |host|
			Mandar.notice "running on #{host}"
			Mandar::Master.run_self_on_host host, [ "server-run", command ]
		end
	end

end
