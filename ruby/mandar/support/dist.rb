module Mandar::Support::Dist

	Mandar::Deploy::Commands.register self, :build
	Mandar::Deploy::Commands.register self, :fetch
	Mandar::Deploy::Commands.register self, :rsync
	Mandar::Deploy::Commands.register self, :untar
	Mandar::Deploy::Commands.register self, :unzip

	def self.command_build build_elem

		build_flag_name =
			build_elem.attributes["flag-name"]

		build_flag_value =
			build_elem.attributes["flag-value"]

		build_message =
			build_elem.attributes["message"]

		build_flag_user =
			build_elem.attributes["user"]

		build_flag_group =
			build_elem.attributes["group"]

		Mandar::Deploy::Flag.set_flag \
			build_flag_name,
			build_flag_value \
		do

			Mandar::notice build_message

			Mandar::Support::Core.tmpdir \
				:user => build_flag_user,
				:group => build_flag_group \
			do

				Mandar::Deploy::Commands.perform build_elem

			end

		end

	end

	def self.command_fetch fetch_elem

		require "net/http"

		fetch_url =
			fetch_elem["url"]

		fetch_user =
			fetch_elem["user"]

		fetch_group =
			fetch_elem["group"]

		fetch_mode =
			fetch_elem["mode"]

		fetch_uri =
			URI fetch_url

		data =
			Net::HTTP.get fetch_uri

		filename =
			File.basename fetch_uri.path

		File.open filename, "w" do |f|
			f.print data
		end

		File.new(filename).chown \
			fetch_user,
			fetch_group,

		if fetch_mode
			File.chmod \
				fetch_mode.to_i(8),
				filename
		end

	end

	def self.command_rsync rsync_elem

		rsync_from =
			rsync_elem.attributes["from"]

		rsync_to =
			rsync_elem.attributes["to"]

		rsync_key =
			rsync_elem.attributes["key"]

		rsync_no_strict_key =
			rsync_elem.attributes["no-strict-key"] != "yes"

		args = [
			"rsync",
			"--archive",
			"--delete",
		]

		if rsync_key || rsync_no_strict_key

			ssh_args = [
				"ssh",
			]

			if rsync_key
				ssh_args += [
					"-i",
					rsync_key,
				]
			end

			if rsync_no_strict_key
				ssh_args += [
					"-o",
					"StrictHostKeyChecking=no",
				]
			end

			args += [
				"--rsh",
				Mandar.shell_quote(ssh_args),
			]

		end

		args += [
			"#{rsync_from}/",
			"#{rsync_to}/",
		]

		Mandar::Support::Core.shell \
			Mandar.shell_quote(args)

	end

	def self.command_untar untar_elem

		untar_archive =
			untar_elem.attributes["archive"]

		args = [
			"tar",
			"--extract",
			"--file", untar_archive,
			"--gunzip",
			"--no-same-owner",
			"--no-same-permissions",
		]

		Mandar::Support::Core.shell \
			Mandar.shell_quote(args)

	end

	def self.command_unzip unzip_elem

		unzip_archive =
			unzip_elem.attributes["archive"]

		unzip_dir =
			unzip_elem.attributes["dir"]

		args = [
			"unzip",
			unzip_archive,
		]

		if unzip_dir
			args += [ "-d", unzip_dir ]
		end

		Mandar::Support::Core.shell \
			Mandar.shell_quote(args)

	end

end
