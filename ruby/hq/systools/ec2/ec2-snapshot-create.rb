require "hq/systools/ec2"

class HQ::SysTools::EC2::Ec2SnapshotCreateScript

	attr_accessor :args
	attr_accessor :exit_code

	def initialize

		require "hq/tools/lock"
		require "mandar"
		require "xml"

		@exit_code = 0

	end

	def debug

		return unless $stdin.tty?

		$stderr.puts msg

	end

	def main

		if args.count != 1

			$stderr.puts "Syntax error"

			@exit_code = 1

			return

		end

		config_doc =
			XML::Document.file args[0]

		@config_elem =
			config_doc.root

		lock_filename =
			@config_elem.attributes["lock"]

		state_filename =
			@config_elem.attributes["state"]

		# load state

		now =
			Time.now.utc

		if File.exist? state_filename

			state_minute =
				File.read(state_filename).to_i

		else

			state_minute = now.min

			File.open state_filename, "w" do |f|
				f.print "#{state_minute}\n"
			end

		end

		@exit_code = 0

		return if state_minute == now.min

		HQ::Tools::Lock.lock lock_filename do

			while now.min != state_minute

				do_minute \
					state_minute < now.min ?
						now.hour : now.hour - 1,
					state_minute

				state_minute =
					(state_minute + 1) % 60

				File.open state_filename, "w" do |f|
					f.print "#{state_minute}\n"
				end

			end

		end

	end

	def do_minute hour, minute

		# iterate accounts

		@config_elem.find("aws-account").each do |aws_account_elem|

			aws_account_name =
				aws_account_elem.attributes["name"]

			access_key_id =
				aws_account_elem.attributes["access-key-id"]

			secret_access_key =
				aws_account_elem.attributes["secret-access-key"]

			# iterate region

			@config_elem.find("ec2-region").each do |ec2_region_elem|

				ec2_region_name =
					ec2_region_elem.attributes["name"]

				ec2_region_endpoint =
					ec2_region_elem.attributes["endpoint"]

				do_account_region \
					hour, minute,
					aws_account_name,
					access_key_id,
					secret_access_key,
					ec2_region_name,
					ec2_region_endpoint

			end

		end

	end

	def do_account_region \
			hour, minute,
			aws_account_name,
			access_key_id,
			secret_access_key,
			ec2_region_name,
			ec2_region_endpoint

		# create aws account

		account = Mandar::AWS::Account.new
		account.name = aws_account_name
		account.access_key_id = access_key_id
		account.secret_access_key = secret_access_key

		# create aws client

		aws_client =
			Mandar::AWS::Client.new \
				account,
				ec2_region_endpoint,
				"2010-08-31"

		aws_client.default_prefix = "a"

		# iterate volumes

		account_xp = "
			@aws-account = '#{aws_account_name}'
		"

		zone_names_xp = "
			.. / ec2-availability-zone [
				@region = '#{ec2_region_name}'
			] / @name"

		zone_xp = "
			@availability-zone = #{zone_names_xp}
		"

		volumes_xp = "
			volume [
				#{account_xp} and #{zone_xp}
			]
		"

		daily_hour =
			@config_elem.attributes["daily-hour"].to_i

		@config_elem.find(volumes_xp).each do |volume_elem|

			host =
				volume_elem.attributes["host"]

			volume_id =
				volume_elem.attributes["volume-id"]

			volume_minute =
				volume_elem.attributes["minute"]

			volume_frequency =
				volume_elem.attributes["frequency"]

			next \
				unless volume_minute == minute.to_s

			next \
				if volume_frequency == "daily" \
					&& hour != daily_hour

			do_volume \
				aws_client,
				host,
				volume_id

		end

	end

	def do_volume \
			aws_client,
			host,
			volume_id

		# create snapshot

		success = false

		3.times do |try|

			begin

				response =
					aws_client.create_snapshot({
						:volume_id => volume_id,
						:description => "automated backup of #{host}",
					})

				snapshot_id =
					response.find_first("a:snapshotId").content

				debug "snapshot for #{host} #{volume_id}: #{snapshot_id}"

				success = true

				break

			rescue Timeout::Error => e

				$stderr.puts "timeout creating snapshot for #{host} " +
					"#{volume_id}: #{e.message}"

				sleep 1

			rescue => e

				$stderr.puts "error creating snapshot for #{host} " +
					"#{volume_id}: #{e.message}"

				sleep 1

			end
		end

		unless success

			$stderr.puts "snapshot for #{host} #{volume_id}: FAILED"

			@exit_code = 1

		end

	end

end
