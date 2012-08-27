module Mandar::Support::Core

	def self.auto_clean(glob, flag = nil)
		Dir.glob glob do |path|
			next if @keepers.include? path
			Mandar::Deploy::Flag.clear "#{flag}-#{file}" if flag
			Mandar::Support::Core.delete path
		end
	end

	def self.keep(file)
		@keepers ||= Set.new
		@keepers << file
	end

	def self.would_create
		return @would_create ||= Set.new
	end

	def self.would_exist? path
		return true if $mock and would_create.include? path
		return File.exist? path
	end

	def self.create_link(value, link, options = {})

		# default values for options
		options[:target_missing] ||= :error

		# check options are valid
		[ :error, :ignore, :delete ].include? options[:target_missing] \
			or raise "Invalid value for target_missing: #{options[:target_missing]}"

		# check target exists
		target = File.expand_path(value, File.dirname(link))
		target_exists = would_exist? target

		# error if target doesn't exist
		if ! target_exists && options[:target_missing] == :error
			Mandar.die "Link target doesn't exist: #{target}, for: #{link}"
		end

		# delete if target doesn't exist
		if ! target_exists && options[:target_missing] == :delete
			return delete link
		end

		# mark link as keeper
		keep link

		begin
			return false if File.readlink(link) == value
		rescue Errno::ENOENT, Errno::EINVAL
			# do nothing
		end

		Mandar.notice "creating link #{link}"
		Mandar::Deploy::Flag.auto

		begin
			FileUtils.remove_entry_secure link
		rescue Errno::ENOENT
			# do nothing
		end

		File.symlink value, link unless $mock

		return true
	end

	# create a directory and set permissions
	def self.create_dir(dir, options = {})

		# mark as keeper
		keep dir

		exists = File.exists?(dir)
		stat = exists ? File.stat(dir) : nil
		raise "File exists: #{dir}" if exists && ! stat.directory?

		changes = false
		changes = true if ! exists
		changes = true if exists && options[:owner] && stat.uid != to_uid(options[:owner])
		changes = true if exists && options[:group] && stat.gid != to_gid(options[:group])
		changes = true if exists && options[:mode] && stat.mode & 0xfff != options[:mode]
		return false unless changes

		Mandar::Deploy::Flag.auto

		Mandar.notice exists ? "setting permissions on #{dir}" : "creating dir #{dir}"

		Dir.mkdir dir unless exists or $mock

		unless $mock

			dir_file = File.new(dir)

			dir_file.chown to_uid(options[:owner]), to_gid(options[:group]) \
				if options[:owner] or options[:group]

			dir_file.chmod options[:mode] if options[:mode]

		end

		return true
	end

	# delete files and directories
	def self.delete(name)
		return false unless File.exists?(name) || File.symlink?(name)
		Mandar.notice "deleting #{name}"
		FileUtils.remove_entry_secure(name) unless $mock
		Mandar::Deploy::Flag.auto
	end

	# install a file and set permissions
	def self.install(src, dest, options = {})
		options[:check] ||= lambda { |path| return true }

		tmp = nil
		begin

			# error if exists as dir
			raise "Dir exists: #{dest}" if File.directory? dest

			# mark file as keeper
			keep dest

			# mark file as would_create
			would_create << dest if $mock

			# stat the file and check there isn't an existing directory with the same name
			exists = File.exists?(dest) && ! File.symlink?(dest)
			stat = exists ? File.stat(dest) : nil

			# write the file if it's a proc
			if src.is_a? Proc
				tmp = Tempfile.open("mandar-")
				src.call tmp
				tmp.flush
				src = tmp.path
			end

			# compare files if it already exists
			content_changes = exists && ! FileUtils.compare_file(src, dest)

			# work out if anything has changed
			changes = false
			changes = true if ! exists
			changes = true if exists && options[:owner] && stat.uid != to_uid(options[:owner])
			changes = true if exists && options[:group] && stat.gid != to_gid(options[:group])
			changes = true if exists && options[:mode] && stat.mode & 0xfff != options[:mode]
			changes = true if content_changes
			return false unless changes

			# notice and flags
			Mandar::Deploy::Flag.auto

			# remove existing symlink
			if File.symlink? dest
				Mandar.notice "removing symlink #{dest}"
				FileUtils.remove_entry_secure dest
			end

			# notice
			Mandar.notice case
				when ! exists; "creating #{dest}"
				when content_changes; "updating #{dest}"
				else "updating permissions on #{dest}"
			end

			# diff
			diff src, dest

			# check
			unless options[:check].call src
				Mandar.error "check failed for #{dest}"
				return false
			end

			unless $mock

				# copy the file
				FileUtils.cp src, dest

				dest_file = File.new dest

				# set owner and/or group
				dest_file.chown to_uid(options[:owner]), to_gid(options[:group]) \
					if options[:owner] or options[:group]

				# set mode
				dest_file.chmod options[:mode] if options[:mode]
			end

			return true

		ensure
			tmp.unlink if tmp
		end
	end

	def self.diff src, dest

		# output diff

		exists = File.exists? dest

		ret = shell_real Mandar.shell_quote %W[
			diff
			--unified=3
			--ignore-space-change
			#{exists ? dest : "/dev/null"}
			#{src}
		]

		if Mandar.logger.format == :html
			html = "<div class=\"mandar-diff\">\n"
		end

		ret[:output].each do |line|

			line_type = case line
				when /^---/; :minus_minus_minus
				when /^\+\+\+/; :plus_plus_plus
				when /^@@/; :at_at
				when /^-/; :minus
				when /^\+/; :plus
				else :else
			end

			if Mandar.logger.format == :html
				div_class = "mandar-diff-#{line_type.to_s.gsub("_","-")}"
				html += "<div class=\"#{div_class}\">#{CGI::escapeHTML line}" +
					"</div>\n"
			else
				Mandar.detail line, \
					:colour => Mandar::Tools::Logger::DIFF_COLOURS[line_type]
			end
		end

		if Mandar.logger.format == :html
			html += "</div>"
			Mandar.message html, :detail, :html => true
		end
	end

	def self.diff src, dest

		dest = "/dev/null" unless File.exists? dest

		ret = shell_real "diff --unified=3 --ignore-space-change #{dest} #{src}"

		if Mandar.logger.format == :html
			html = "<div class=\"mandar-diff\">\n"
		end

		ret[:output].each do |line|

			line_type = case line
				when /^---/; :minus_minus_minus
				when /^\+\+\+/; :plus_plus_plus
				when /^@@/; :at_at
				when /^-/; :minus
				when /^\+/; :plus
				else :else
			end

			if Mandar.logger.format == :html
				div_class = "mandar-diff-#{line_type.to_s.gsub("_","-")}"
				html += "<div class=\"#{div_class}\">#{CGI::escapeHTML line}" +
					"</div>\n"
			else
				Mandar.detail line, \
					:colour => Mandar::Tools::Logger::DIFF_COLOURS[line_type]
			end
		end

		if Mandar.logger.format == :html
			html += "</div>"
			Mandar.message html, :detail, :html => true
		end

	end

	def self.shell(cmd, options = {})
		options[:log] = Mandar.logger.format != :html
		options[:level] ||= :detail
		ret = shell_real(cmd, options)
		Mandar.message(([ cmd ] + ret[:output]).join("\n"), options[:level]) if Mandar.logger.format == :html
		return ret[:status] == 0
	end

	def self.shell_real cmd, options = {}

		options[:level] ||= :detail

		Mandar.debug "shell #{cmd}"

		# run the subprocess with output to a pipe and no input
		rd, wr = IO.pipe
		pid = fork do
			rd.close
			$stdout.reopen wr
			$stderr.reopen wr
			$stdin.reopen File.open("/dev/null", "r")
			exec "/bin/bash", "-c", cmd
		end
		wr.close

		# read from the pipe while checking if the command has closed
		output = []
		buf = ""
		while true
			if select([rd], nil, nil, 1)
				if rd.eof?
					Process.wait(pid)
					break
				end
				data = rd.read_nonblock(1024)
				buf += data
				while buf.index("\n")
					line, buf = buf.split("\n", 2)
					Mandar.message line, options[:level] if options[:log]
					output << line
				end
			else
				break if Process.wait(pid, Process::WNOHANG)
			end
		end

		# and return
		return {
			:status => $?.exitstatus,
			:output => output,
		}
	end

	# get the uid from a user name
	def self.to_uid(user)
		return nil unless user
		user = user.to_s
		return user =~ /^\d+$/ ? user.to_i : Etc.getpwnam(user).uid
	end

	# get the gid from a group name
	def self.to_gid(group)
		return nil unless group
		group = group.to_s
		return group =~ /^\d+$/ ? group.to_i : Etc.getgrnam(group).gid
	end

	Mandar::Deploy::Commands.register self, :sub_task

	def self.command_sub_task referring_sub_task_elem

		sub_task_name =
			referring_sub_task_elem.attributes["name"]

		referred_sub_task =
			$sub_tasks_by_task[sub_task_name]

		referred_sub_task \
			or raise "No such sub-task: #{sub_task_name}"

		Mandar::Deploy::Commands.perform \
			referred_sub_task

	end

	# TODO move these

	Mandar::Deploy::Commands.register self, :auto_clean
	Mandar::Deploy::Commands.register self, :chdir
	Mandar::Deploy::Commands.register self, :clean
	Mandar::Deploy::Commands.register self, :delete
	Mandar::Deploy::Commands.register self, :dir
	Mandar::Deploy::Commands.register self, :file
	Mandar::Deploy::Commands.register self, :http_get
	Mandar::Deploy::Commands.register self, :keep
	Mandar::Deploy::Commands.register self, :link
	Mandar::Deploy::Commands.register self, :install
	Mandar::Deploy::Commands.register self, :shell
	Mandar::Deploy::Commands.register self, :shell_if
	Mandar::Deploy::Commands.register self, :tmpdir
	Mandar::Deploy::Commands.register self, :unpack

	def self.command_auto_clean(auto_clean_elem)

		auto_clean_glob = auto_clean_elem.attributes["glob"]
		auto_clean_flag = auto_clean_elem.attributes["flag"]

		auto_clean auto_clean_glob, auto_clean_flag
	end

	def self.command_chdir(chdir_elem)

		chdir_dir = chdir_elem.attributes["dir"]

		Dir.chdir chdir_dir unless $mock
	end

	def self.command_delete(delete_elem)

		delete_name = delete_elem.attributes["name"]

		delete delete_name
	end

	def self.command_dir(dir_elem)

		dir_name = dir_elem.attributes["name"]
		dir_mode = dir_elem.attributes["mode"]
		dir_user = dir_elem.attributes["user"]
		dir_group = dir_elem.attributes["group"]

		options = {}
		options[:mode] = dir_mode.to_i(8) if dir_mode
		options[:owner] = dir_user if dir_user
		options[:group] = dir_group if dir_group

		create_dir dir_name, options
	end

	def self.command_file(file_elem)

		file_name = file_elem.attributes["name"]
		file_format = file_elem.attributes["format"]
		file_mode = file_elem.attributes["mode"]
		file_user = file_elem.attributes["user"]
		file_group = file_elem.attributes["group"]
		file_marker = file_elem.attributes["marker"]
		file_no_check = file_elem.attributes["no-check"] == "yes"

		file_name or Mandar.die "No file name specified in #{service_name}"
		file_format or Mandar.die "No format specified for #{file_name}"
		Mandar::Deploy::Formats.exists? file_format \
			or Mandar.die "Unrecognised file format #{file_format} for #{file_name}"

		options = {}
		options[:mode] = file_mode.to_i(8) if file_mode
		options[:owner] = file_user if file_user
		options[:group] = file_group if file_group

		Mandar.debug "attempting to update #{file_name}"
		if file_marker
			output_proc = lambda { |f_out|
				File.open(file_name, "r") do |f_in|

					# copy up to start marker, or end of file
					while line = f_in.gets and line.chomp != "#{file_marker} start"
					f_out.puts(line)
					end

					# ignore up to end marker, or end of file
					nil while line = f_in.gets and line.chomp != "#{file_marker} end"

					# output markers and call format function
					f_out.puts "#{file_marker} start"
					Mandar::Deploy::Formats.invoke file_format, file_elem, f_out
					f_out.puts "#{file_marker} end"

					# copy remainder
					f_out.puts line while line = f_in.gets

				end
			}
			check_proc = lambda { |path| Mandar::Deploy::Formats.check file_format, path }
			options[:check] = check_proc unless file_no_check
			install output_proc, file_name, options

		else
			output_proc = lambda { |f| Mandar::Deploy::Formats.invoke file_format, file_elem, f }
			check_proc = lambda { |path| Mandar::Deploy::Formats.check file_format, path }
			options[:check] = check_proc unless file_no_check
			install output_proc, file_name, options
		end
	end

	def self.http_get(url, dst)

		curl_args = %W[
			curl
			--fail
			--silent
			--show-error
			--output #{dst}
			#{url}
		]
		curl_cmd = Mandar.shell_quote curl_args

		shell curl_cmd or raise "Error executing: #{curl_cmd}" unless $mock
	end

	def self.command_http_get(http_get_elem)

		http_get_url = http_get_elem.attributes["url"]
		http_get_dst = http_get_elem.attributes["dst"]

		url = http_get_url
		dst = http_get_dst || File.basename(url)

		http_get url, dst
	end

	def self.command_unpack(unpack_elem)

		unpack_url = unpack_elem.attributes["url"]

		Tempfile.open("mandar") do |tmp|

			case unpack_url

			when /\.tar\.gz$/
				args = %W[
					tar
					--extract
					--gzip
					--no-same-owner
					--file #{tmp.path}
				]

			else
				raise "Can't unpack #{unpack_url}"

			end

			http_get unpack_url, tmp.path

			cmd = Mandar.shell_quote args
			shell cmd or raise "Error executing: #{cmd}" unless $mock

		end
	end

	def self.command_keep(keep_elem)

		keep_name = keep_elem.attributes["name"]

		Mandar::Support::Core.keep keep_name
	end

	def self.command_link(link_elem)

		link_src = link_elem.attributes["src"]
		link_dst = link_elem.attributes["dst"]
		link_target_missing = link_elem.attributes["target-missing"] || "error"

		options = {
			:target_missing => link_target_missing.to_sym
		}

		create_link link_src, link_dst, options
	end

	def self.command_install(install_elem)

		install_src = install_elem.attributes["src"]
		install_dst = install_elem.attributes["dst"]
		install_mode = install_elem.attributes["mode"]
		install_user = install_elem.attributes["user"]
		install_group = install_elem.attributes["group"]

		options = {}
		options[:mode] = install_mode.to_i(8) if install_mode
		options[:owner] = install_user if install_user
		options[:group] = install_group if install_group

		install install_src, install_dst, options
	end

	def self.command_shell(shell_elem)
		shell_user = shell_elem.attributes["user"]

		cmd = ""

		shell_cmd = shell_elem.attributes["cmd"]
		cmd += shell_cmd if shell_cmd

		shell_elem.find("*").each do |elem|
			case elem.name

				when "env"
					env_name = elem.attributes["name"]
					env_value = elem.attributes["value"]
					cmd += " " unless cmd.empty?
					cmd += "#{env_name}=#{Mandar.shell_quote env_value}"

				when "arg"
					arg_name = elem.attributes["name"]
					arg_value = elem.attributes["value"]
					if arg_name
						cmd += " " unless cmd.empty?
						cmd += "#{arg_name}"
					end
					if arg_value
						cmd += " " unless cmd.empty?
						cmd += "#{Mandar.shell_quote arg_value}"
					end

				else
					raise "Invalid element in <shell>: <#{elem.name}>"
			end
		end

		if shell_user
			cmd = Mandar.shell_quote %W[ sudo -u #{shell_user} /bin/bash -c #{cmd} ]
		end

		Mandar::Deploy::Flag.auto
		shell cmd or raise "Error executing: #{cmd}" unless $mock
	end

	def self.command_shell_if(shell_if_elem)

		shell_if_cmd = shell_if_elem.attributes["cmd"]

		return if $mock

		system shell_if_cmd or return

		Mandar::Deploy::Commands.perform shell_if_elem
	end

	def self.tmpdir &proc

		old_dir = Dir.pwd

		begin

			Dir.mktmpdir do |new_dir|
				Dir.chdir new_dir
				proc.call
			end

		ensure

			Dir.chdir old_dir

		end

	end

	def self.command_tmpdir tmpdir_elem

		tmpdir do
			Mandar::Deploy::Commands.perform tmpdir_elem
		end

	end

end
