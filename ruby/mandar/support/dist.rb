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

		Mandar::Deploy::Flag.set_flag \
			build_flag_name,
			build_flag_value \
		do

			Mandar::notice build_message

			Mandar::Support::Core.tmpdir do

				Mandar::Deploy::Commands.perform build_elem

			end

		end

	end

	def self.command_fetch fetch_elem

		require "net/http"

		fetch_url =
			fetch_elem.attributes["url"]

		fetch_uri =
			URI fetch_url

		data =
			Net::HTTP.get fetch_uri

		filename =
			File.basename fetch_uri.path

		File.open filename, "w" do |f|
			f.print data
		end

	end

	def self.command_rsync rsync_elem

		rsync_from =
			rsync_elem.attributes["from"]

		rsync_to =
			rsync_elem.attributes["to"]

		args = [
			"rsync",
			"--archive",
			"--delete",
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

		args = [
			"unzip",
			unzip_archive,
		]

		Mandar::Support::Core.shell \
			Mandar.shell_quote(args)

	end

end
