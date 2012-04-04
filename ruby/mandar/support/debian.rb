module Mandar::Debian

	def self.apt_packages(force = false)
		return @apt_packages if @apt_packages && ! force
		apt_packages = []
		%x[
			dpkg-query -W --showformat '${Status}:${Package}:${Provides}\n'
		].split("\n").each do |line|
			status, package, provides = line.split ":"
			next unless status == "install ok installed"
			apt_packages += package.split ", "
			apt_packages += provides.split ", " if provides
		end
		return @apt_packages = apt_packages
	end

	def self.apt_install(*names)

		names_to_install = names - apt_packages
		return if names_to_install.empty?

		names_to_install_str = names_to_install.join ' '

		Mandar.detail "updating package cache"
		full_cmd = "apt-get -y update"
		Mandar::Support::Core.shell full_cmd or raise "Error executing #{full_cmd}" unless $mock

		Mandar.notice "installing #{names_to_install_str}"
		apt_cmd = Mandar.shell_quote(%W[ apt-get -y install ] + names_to_install)
		full_cmd = "DEBIAN_FRONTEND=noninteractive #{apt_cmd}"
		Mandar::Support::Core.shell full_cmd or raise "Error executing #{full_cmd}" unless $mock

		apt_packages(true)
	end

	def self.apt_remove(*names)

		names_to_remove = names & apt_packages
		return if names_to_remove.empty?

		names_to_remove_str = names_to_remove.join ' '

		Mandar.detail "updating package cache"
		system "apt-get -q2 update" or raise "Error" unless $mock

		Mandar.notice "remove #{names_to_remove_str}"
		apt_cmd = Mandar.shell_quote(%W[ apt-get -y remove ] + names_to_remove)
		system "#{apt_cmd}" or raise "Error" unless $mock

		apt_packages(true)
	end

	# manage debconf entries
	def self.debconf_set_selections(*entries)
		unless @debconf
			@debconf = {}
			apt_install "debconf-utils"
			a = Time.now
			`debconf-get-selections`.split("\n").select { |s| s !~ /^#/ }.map { |s| s.split("\t", 4) }.each do |line|
				package, question, type, value = line
				@debconf[question] = { :type => type, :value => value }
			end
			b = Time.now
			Mandar.debug "debconf-get-selections took #{((b-a)*1000).to_i}ms"
		end

		Mandar.debug "opening pipe to debconf-set-selections"
		cmd = $mock ? "cat >/dev/null" : "debconf-set-selections"
		IO.popen cmd, "w" do |f|
			entries.each do |entry|
				package = entry[:package]
				question = entry[:question]
				type = entry[:type]
				value = entry[:value] || ""

				next if @debconf[question] && @debconf[question][:value] == value

				Mandar.notice "setting debconf: #{question} = #{value}"
				line = "#{package} #{question} #{type} #{value}"
				Mandar.debug "writing #{line} to debconf-set-selections"
				f.puts line

				@debconf[question] = value
				Mandar::Deploy::Flag.auto
			end
		end
		Mandar.debug "closed pipe to debconf-set-selections"
	end

	# interface to debian's dpkg-statoverride command
	def self.dpkg_statoverride(user, group, mode, path)
		uid = Mandar::Support::Core.to_uid(user)
		gid = Mandar::Support::Core.to_gid(group)

		# initialise list of existing overrides
		unless @statoverrides
			@statoverrides = {}
			`dpkg-statoverride --list`.split("\n").each do |line|
				(line_user, line_group, line_mode, line_path) = line.split(" ")
				@statoverrides[line_path] = {
				    :user => line_user,
				    :group => line_group,
				    :mode => line_mode.to_i(8),
				}
			end
		end

		# do nothing if no changes
		statoverride = @statoverrides[path]
		return false if statoverride &&
			statoverride[:user] == user &&
			statoverride[:group] == group &&
			statoverride[:mode] == mode

		# output a message
		Mandar.notice "setting permissions for #{path}"
		Mandar::Deploy::Flag.auto

		# remove existing
		system "dpkg-statoveride --remote #{path}" if statoverride unless $mock

		# add new
		system "dpkg-statoverride --add --update #{user} #{group} 0#{mode.to_s(8)} #{path}" unless $mock

		# update list
		@statoverrides[path] = {
			:user => user,
			:group => group,
			:mode => mode,
		}

		return true
	end

	def self.runlevel_update(service, *start_levels)
		start_levels.flatten!
		start_levels.map! { |level| level.to_i }
		raise "No such service: #{service}" unless File.exists? "/etc/init.d/#{service}"
		Dir.glob("/etc/rc?.d").each do |rc_dir|
			level = rc_dir[7...8].to_i
			Dir.glob("#{rc_dir}/[SK][0-9][0-9]#{service}").each do |rc_file|
				old_status = rc_file[11...12]
				new_status = start_levels.include?(level) ? "S" : "K"
				next if old_status == new_status
				new_file = rc_file.clone
				new_file[11] = new_status
				Mandar.notice "renaming #{rc_file} to #{new_file}"
				FileUtils.mv rc_file, new_file unless $mock
				Mandar::Deploy::Flag.auto
			end
		end
	end

	Mandar::Deploy::Commands.register self, :apt
	Mandar::Deploy::Commands.register self, :apt_install
	Mandar::Deploy::Commands.register self, :apt_remove
	Mandar::Deploy::Commands.register self, :debconf
	Mandar::Deploy::Commands.register self, :runlevel_update
	Mandar::Deploy::Commands.register self, :statoverride
	Mandar::Deploy::Commands.register self, :update_enabled
	Mandar::Deploy::Commands.register self, :update_rcd

	def self.command_apt(apt_elem)

		apt_packages = apt_elem.attributes["packages"]
		names = apt_packages.split

		apt_install *names
	end

	def self.command_apt_install(apt_elem)

		apt_package = apt_elem.attributes["package"]

		apt_install *apt_package
	end

	def self.command_apt_remove(apt_elem)

		apt_package = apt_elem.attributes["package"]

		apt_remove *apt_package
	end

	def self.command_debconf(debconf_elem)

		debconf_package = debconf_elem.attributes["package"]
		debconf_question = debconf_elem.attributes["question"]
		debconf_type = debconf_elem.attributes["type"]
		debconf_value = debconf_elem.attributes["value"]

		debconf_set_selections({
			:package => debconf_package,
			:question => debconf_question,
			:type => debconf_type,
			:value => debconf_value,
		})
	end

	def self.command_runlevel_update(runlevel_update_elem)

		runlevel_update_service = runlevel_update_elem.attributes["service"]
		runlevel_update_levels = runlevel_update_elem.attributes["levels"]

		runlevel_update runlevel_update_service, runlevel_update_levels.scan(/./)
	end

	def self.command_statoverride(statoverride_elem)

		statoverride_name = statoverride_elem.attributes["name"]
		statoverride_user = statoverride_elem.attributes["user"]
		statoverride_group = statoverride_elem.attributes["group"]
		statoverride_mode = statoverride_elem.attributes["mode"]

		dpkg_statoverride statoverride_user, statoverride_group, statoverride_mode.to_i(8), statoverride_name
	end

	def self.command_update_rcd(ur_elem)

		ur_name = ur_elem.attributes["name"]

		return if Dir.glob("/etc/rc?.d/[SK]??#{ur_name}").length > 0

		Mandar.notice "creating /etc/rc?.d links for #{ur_name}"
		Mandar::Deploy::Flag.auto

		system "update-rc.d #{ur_name} defaults" or raise "Error" unless $mock
	end

end
