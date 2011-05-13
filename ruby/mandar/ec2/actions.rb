module Mandar::EC2::Actions

	Mandar::Master::Actions.register self, :host, :create, :resize, :stop, :start

	def self.host_create(cdb, host)

		raise "Invalid state #{host["state"]} for create" unless host["state"] == "new"
		Mandar.notice "creating host #{host["name"]}"
		aws_account = cdb.get("aws-account/#{host["aws-account"]}")
		domain = cdb.get("domain/#{host["domain"]}")
		root_ssh_key_name = Mandar::Core::Config.mandar.attributes["ssh-key-name"]
		root_ssh_key = cdb.get("ssh-key/#{root_ssh_key_name}")

		ssh_key_name = Mandar::Core::Config.mandar.attributes["ssh-key-name"]
		ssh_key_elem = Mandar::Core::Config.abstract["ssh-key"].find_first("*[@name='#{ssh_key_name}']")
		ssh_key = ssh_key_elem.content

		options = {
			:aws_account => {
				:name => aws_account["name"],
				:ssh_key => aws_account["ssh-key"],
			},
			:ami_id => host["ec2-machine-id"],
			:availability_zone => host["ec2-availability-zone"],
			:volume_id => host["ec2-volume-size"].to_i,
			:security_groups => [
				"default",
				"#{domain["short-name"]}-domain",
				"#{host["class"]}-class",
			],
			:instance_type => host["ec2-instance-type"],
			:ssh_key => {
				:public => root_ssh_key["public"],
				:private => root_ssh_key["private"],
			},
		}
		result = Mandar::EC2::Utils.create_instance(options)

		host["public-hostname"] = result[:public_hostname]
		host["public-ip"] = result[:public_ip]
		host["private-hostname"] = result[:private_hostname]
		host["private-ip"] = result[:private_ip]
		host["ssh-host-key"] = result[:ssh_host_key]
		host["ec2-instance-id"] = result[:ec2_instance_id]
		host["ec2-volume-id"] = result[:ec2_volume_id]
		host["state"] = "running"
		host["action"] = ""
		cdb.update(host)
	end

	def self.host_resize(cdb, host)
		raise "not complete"

		host["ec2-root-device-type"] == "ebs" \
			or raise "Host #{host["name"]} has invalid root type #{host["ec2-root-device-type"]} for resize"
		host["state"] == "running" \
			or raise "Host #{host["name"]} has invalid state #{host["state"]} for resize"
		aws_account = cdb.get("aws-account/#{host["aws-account"]}")
		domain = cdb.get("domain/#{host["domain"]}")

		# stop host
		options = {
			:aws_account => { :name => aws_account["name"] },
			:instance_id => host["ec2-instance-id"],
		}
		result = Mandar::EC2::Utils.stop_instance(options)

		# create new host
		options = {
			:aws_account => {
				:name => aws_account["name"],
				:ssh_key => aws_account["ssh-key"],
			},
			:ami_id => host["ec2-machine-id"],
			:availability_zone => host["ec2-availability-zone"],
			:volume_id => host["ec2-volume-id"],
			:security_groups => [
				"default",
				"#{domain["short-name"]}-domain",
				"#{host["class"]}-class",
			],
			:instance_type => host["ec2-instance-type"],
		}
		result = Mandar::EC2::Utils.create_instance(options)

		# update host in database
		host["public-hostname"] = result[:public_hostname]
		host["public-ip"] = result[:public_ip]
		host["private-hostname"] = result[:private_hostname]
		host["private-ip"] = result[:private_ip]
		host["ssh-host-key"] = result[:ssh_host_key]
		host["ec2-instance-id"] = result[:ec2_instance_id]
		host["ec2-volume-id"] = result[:ec2_volume_id]
		host["state"] = "running"
		host["action"] = ""
		cdb.update(host)
	end

	def self.host_stop(cdb, host)

		host["ec2-root-device-type"] == "ebs" \
			or raise "Host #{host["name"]} has invalid root type #{host["ec2-root-device-type"]} for stop"
		host["state"] == "running" \
			or raise "Host #{host["name"]} has invalid state #{host["state"]} for stop"

		aws_account = cdb.get("aws-account/#{host["aws-account"]}")

		options = {
			:aws_account => { :name => aws_account["name"] },
			:instance_id => host["ec2-instance-id"],
		}
		result = Mandar::EC2::Utils.stop_instance(options)

		host["public-hostname"] = ""
		host["public-ip"] = ""
		host["private-hostname"] = ""
		host["private-ip"] = ""
		host["state"] = "stopped"
		host["action"] = ""
		cdb.update(host)
	end

	def self.host_start(cdb, host)

		host["ec2-root-device-type"] == "ebs" \
			or raise "Host #{host["name"]} has invalid root type #{host["ec2-root-device-type"]} for stop"
		host["state"] == "stopped" \
			or raise "Host #{host["name"]} has invalid state #{host["state"]} for stop"

		aws_account = cdb.get("aws-account/#{host["aws-account"]}")

		options = {
			:aws_account => { :name => aws_account["name"] },
			:instance_id => host["ec2-instance-id"],
		}
		result = Mandar::EC2::Utils.start_instance(options)

		host["public-hostname"] = result[:public_hostname]
		host["public-ip"] = result[:public_ip]
		host["private-hostname"] = result[:private_hostname]
		host["private-ip"] = result[:private_ip]
		host["state"] = "running"
		host["action"] = ""
		cdb.update(host)
	end
end
