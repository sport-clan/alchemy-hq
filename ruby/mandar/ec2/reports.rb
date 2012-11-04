module Mandar::EC2::Reports

	def self.instances(ec2)

		require "hq/tools/table"

		config = Mandar::Core::Config.config

		ret = ec2.describe_instances

		table = HQ::Tools::Table.new

		table.push [
			"Res ID",
			"Inst ID",
			"Image ID",
			"Avail zone",
			"State",
			"Public IP",
			"Name",
		]

		if ret.reservationSet

			for reservation in ret.reservationSet.item
				for instance in reservation.instancesSet.item
					host = config.find_first("host[@ec2-instance-id='#{instance.instanceId}']")
					table.push [
						reservation.reservationId,
						instance.instanceId,
						instance.imageId,
						instance.placement.availabilityZone,
						instance.instanceState.name,
						instance.ipAddress || "-",
						host ? host.attributes["name"] : "-",
					]
				end
			end

			table.print

		else
			puts "no instances to display"
		end
	end

	def self.snapshots_summary(ec2)

		require "hq/tools/table"

		config = Mandar::Core::Config.config

		table = HQ::Tools::Table.new

		table.push [
			"Volume ID",
			"#",
			"Oldest",
			"Newest",
			"Host",
			"Instance ID",
			"Policy",
		]

		snapshots = ec2.describe_snapshots({
			:owner => "self",
		})
		volumes = {}
		snapshots.snapshotSet.item.each do |item|
			unless volumes[item.volumeId]
				volumes[item.volumeId] = {
					:snapshots => [],
					:oldest => item,
					:newest => item,
				}
			end
			volume = volumes[item.volumeId]
			volume[:snapshots].push item
			volume[:oldest] = item if item.startTime < volume[:oldest].startTime
			volume[:newest] = item if volume[:newest].startTime < item.startTime
		end
		volumes.each do |volumeId, volume|
			host_elem = config.find_first("host[@ec2-volume-id='#{volumeId}']")
			class_name = host_elem ? host_elem.attributes["class"] : nil
			class_elem = class_name ? config.find_first("class[@name='#{class_name}']") : nil
			backup_elem = class_elem ? class_elem.find_first("backup") : nil
			table.push [
				volumeId,
				volume.snapshots.size,
				"#{volume.oldest.startTime[0...10]} #{volume.oldest.startTime[11...16]}",
				"#{volume.newest.startTime[0...10]} #{volume.newest.startTime[11...16]}",
				host_elem ? host_elem.attributes["name"] : "-",
				host_elem ? host_elem.attributes["ec2-instance-id"] : "-",
				backup_elem ? backup_elem.attributes["policy"] : "-",
			]
		end
		table.print
	end
end
