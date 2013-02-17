module Mandar::Support::Dist

	Mandar::Deploy::Commands.register self, :build
	Mandar::Deploy::Commands.register self, :fetch
	Mandar::Deploy::Commands.register self, :rsync
	Mandar::Deploy::Commands.register self, :untar
	Mandar::Deploy::Commands.register self, :unzip

	def self.command_build build_elem

		Mandar::Deploy::Flag.set_flag \
			build_elem["flag-name"],
			build_elem["flag-value"] \
		do

			Mandar::notice build_elem["message"]

			Mandar::Support::Core.tmpdir \
				:user => build_elem["user"],
				:group => build_elem["group"] \
			do

				Mandar::Deploy::Commands.perform \
					build_elem

			end

		end

	end

	def self.command_fetch fetch_elem

		require "net/http"

		fetch_uri =
			URI fetch_elem["url"]

		begin

			http =
				Net::HTTP.new \
					fetch_uri.host,
					fetch_uri.port

			http.use_ssl =
				fetch_uri.scheme == "https"

			request =
				Net::HTTP::Get.new \
					fetch_uri.request_uri

			response =
				http.request request

			raise "Error #{response.code} #{reponse.message}" \
				unless response.code == "200"

			data =
				response.body

		ensure

			begin
				http.finish
			rescue
			end

		end

		filename =
			File.basename fetch_uri.path

		File.open filename, "w" do |f|
			f.print data
		end

		FileUtils.chown \
			fetch_elem["user"],
			fetch_elem["group"],
			filename

		if fetch_elem["mode"]
			File.chmod \
				fetch_elem["mode"].to_i(8),
				filename
		end

	end

	def self.command_rsync rsync_elem

		args = [
			"rsync",
			"--archive",
			"--delete",
		]

		if rsync_elem["key"] || rsync_elem["no-strict-key"] != "yes"

			ssh_args = [
				"ssh",
			]

			if rsync_elem["key"]
				ssh_args += [
					"-i",
					rsync_elem["key"],
				]
			end

			if rsync_elem["no-strict-key"] != "yes"
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
			"#{rsync_elem["from"]}/",
			"#{rsync_elem["to"]}/",
		]

		Mandar::Support::Core.shell \
			Mandar.shell_quote(args)

	end

	def self.command_untar untar_elem

		args = [
			"tar",
			"--extract",
			"--file", untar_elem["archive"],
			"--gunzip",
			"--no-same-owner",
			"--no-same-permissions",
		]

		Mandar::Support::Core.shell \
			Mandar.shell_quote(args),
			:user => untar_elem[:user]

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
