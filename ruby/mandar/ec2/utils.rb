require "mandar/ec2"

module Mandar::EC2::Utils

	def self.connect(account)
		(@connect_lock ||= Mutex.new).synchronize do
			@connect_map ||= {}

			# don't connect twice
			return @connect_map[account] if @connect_map[account]

			# required modules
			require "rubygems"
			require "AWS"

			# connect
			ret = AWS::EC2::Base.new({
				:server => account.server,
				:access_key_id => account.access_key_id,
				:secret_access_key => account.secret_access_key,
			})

			return @connect_map[account] = ret
		end
	end

	def self.get_content(elem, xpath)
		sub_elem = elem.find_first(xpath)
		return sub_elem ? sub_elem.content : nil
	end

	def self.create_instance(options)

		temp_files = []
		begin

			aws_account = options[:aws_account]
			ami_id = options[:ami_id]
			availability_zone = options[:availability_zone]
			volume_id = options[:volume_id]
			dns_name = options[:dns_name]
			security_groups = options[:security_groups]
			instance_type = options[:instance_type]
			ssh_key_public = options[:ssh_key][:public]
			ssh_key_private = options[:ssh_key][:private]

			raise "must specify valide machine id" unless ami_id =~ /^ami-[0-9a-f]{8}$/

			ec2 = Mandar::EC2.connect2(aws_account[:name])

			# write ssh key file
			ssh_key_file = Tempfile.new("mandar-")
			temp_files << ssh_key_file
			File.open(ssh_key_file.path, "w") { |f| f.puts ssh_key_private }
			system "ssh-keygen -y -f #{ssh_key_file.path} -P '' >/dev/null" or
				throw "SSH key invalid or missing"

			# lookup ami
			puts "looking up #{ami_id}..."
			ret = ec2.describe_images :image_id => ami_id
			image = ret.find_first("/a:DescribeImagesResponse/a:imagesSet/a:item")
			image_name = get_content image, "a:name"
			image_root_device_type = get_content image, "a:rootDeviceType"
			image_kernel_id = get_content image, "a:kernelId"
			image_ramdisk_id = get_content image, "a:ramdiskId"
			puts "ami name: #{image_name}" if image_name
			puts "ami root device type: #{image_root_device_type}"

			# create ssh host keys
			puts "creating ssh host keys"
			FileUtils.rm_rf([
				"/tmp/ssh_host_rsa_key",
				"/tmp/ssh_host_rsa_key.pub",
				"/tmp/ssh_host_dsa_key",
				"/tmp/ssh_host_dsa_key.pub",
			])
			system "ssh-keygen -q -f /tmp/ssh_host_rsa_key -t rsa -C host -N ''"
			system "ssh-keygen -q -f /tmp/ssh_host_dsa_key -t dsa -C host -N ''"
			script = [
				"#!/bin/bash",
				"cat <<END >/etc/ssh/ssh_host_rsa_key\n#{File.read("/tmp/ssh_host_rsa_key")}END",
				"cat <<END >/etc/ssh/ssh_host_rsa_key.pub\n#{File.read("/tmp/ssh_host_rsa_key.pub")}END",
				"cat <<END >/etc/ssh/ssh_host_dsa_key\n#{File.read("/tmp/ssh_host_dsa_key")}END",
				"cat <<END >/etc/ssh/ssh_host_dsa_key.pub\n#{File.read("/tmp/ssh_host_dsa_key.pub")}END",
				"service ssh restart",
				"cp /root/.ssh/authorized_keys /root/old-keys",
				"echo #{ssh_key_public} >/root/.ssh/authorized_keys",
				"cp /root/.ssh/authorized_keys /root/new-keys",
				"date >/root/date",
			]
			ssh_host_key = File.read("/tmp/ssh_host_rsa_key.pub").chomp
			puts "ssh host key #{ssh_host_key}"
			FileUtils.rm_rf([
				"/tmp/ssh_host_rsa_key",
				"/tmp/ssh_host_rsa_key.pub",
				"/tmp/ssh_host_dsa_key",
				"/tmp/ssh_host_dsa_key.pub",
			])

			# create ami if cloning ebs instance
			if image_root_device_type && volume_id =~ /^(snap|vol)-/

				raise "TODO - disabled"

				if volume_id =~ /^vol-/

					puts "calling create_snapshot..."
					ret = ec2.create_snapshot({
						:volume_id => volume_id,
					})
					snapshot_id = ret.snapshotId
					created_snapshot = true
					puts "snapshot id: #{snapshot_id}"

					snapshot_status = ""
					ret = nil
					print "waiting for snapshot"
					until snapshot_status == "completed"
						print "."
						sleep 1
						ret = ec2.describe_snapshots({
							:snapshot_id => snapshot_id,
						})
						snapshot = ret.snapshotSet.item[0]
						snapshot_status = snapshot.status
					end
					print "\n"

				else
					snapshot_id = volume_id
					created_snapshot = false
				end

				puts "calling register_image..."
				ami_name = "copy_of_#{volume_id}_#{Time.now.to_i}"
				ret = ec2.register_image({
					:name => ami_name,
					:architecture => "i386",
					:kernel_id => image_kernel_id,
					:ramdisk_id => image_ramdisk_id,
					:root_device_name => "/dev/sda1",
					:block_device_mapping => [{
						:device_name => "/dev/sda1",
						:ebs => {
							:snapshot_id => snapshot_id,
							:delete_on_termination => false,
						},
					}],
				})
				ami_id = ret.imageId
				created_ami = true
				puts "image id: #{ami_id}"

			else
				created_snapshot = false
				created_ami = false
			end

			# run instance
			puts "calling run_instances..."
			ret = ec2.run_instances({
				:image_id => ami_id,
				:key_name => "default-key",
				:security_group => security_groups,
				:instance_type => instance_type,
				:min_count => 1,
				:max_count => 1,
				:placement => {
					:availability_zone => availability_zone,
				},
				:user_data => Base64.encode64(script.join("\n") + "\n"),
				:block_device_mapping => case
					when image_root_device_type != "ebs"; []
					when volume_id.is_a?(Fixnum); [{
						:device_name => "/dev/sda1",
						:ebs => {
							:volume_size => volume_id.to_i,
							:delete_on_termination => false,
						}
					}]
					when volume_id =~ /^(snap|vol)-/; []
					else raise "Invalid volume specification: #{volume_id}"
				end
			})
			instance = ret.find_first("/a:RunInstancesResponse/a:instancesSet/a:item")
			instance_id = get_content instance, "a:instanceId"
			puts "instance id: #{instance_id}"

			# create volume
			unless image_root_device_type == "ebs"
				case volume_id

				when /^([0-9]+)$/i
					puts "calling create_volume, size #{$1}GiB"
					ret = ec2.create_volume({
						:availability_zone => availability_zone,
						:size => "#{$1}",
					})
					volume_id = ret.volumeId

				when /^snap-([0-9a-f]){8}$/
					puts "calling create_volume, using snapshot #{volume_id}"
					ret = ec2.create_volume({
						:availability_zone => availability_zone,
						:snapshot_id => volume_id,
					})
					volume_id = ret.volumeId

				when /^vol-([0-9a-f]){8}$/
					puts "using specified existing volume"

				else
					puts "specified volume_id is invalid: #{volume_id}"
					exit 1

				end
				puts "volume id: #{volume_id}"
			end

			# wait for instance
			instance_state = ""
			ret = nil
			print "waiting for instance..."
			start_time = Time.now
			until instance_state == "running"
				print "."
				sleep 5
				ret = ec2.describe_instances({
					:instance_id => instance_id,
				})
				instance = ret.find_first("/a:DescribeInstancesResponse/a:reservationSet/a:item/a:instancesSet/a:item")
				instance_state = get_content instance, "a:instanceState/a:name"
			end
			print " (#{(Time.now - start_time).to_i} seconds)\n"
			dns_name = get_content instance, "a:dnsName"
			public_ip = get_content instance, "a:ipAddress"
			private_dns_name = get_content instance, "a:privateDnsName"
			private_ip = get_content instance, "a:privateIpAddress"
			volume_id = get_content instance, "a:blockDeviceMapping/a:item/a:ebs/a:volumeId" if image_root_device_type == "ebs"
			puts "volume id #{volume_id}" if image_root_device_type == "ebs"
			puts "public dns: #{dns_name}"
			puts "public ip: #{public_ip}"

			# setup ssh host keys
			system "ssh-keygen -R #{dns_name} 2>/dev/null"
			system "ssh-keygen -R #{public_ip} 2>/dev/null"
			FileUtils.mkdir_p "#{ENV["HOME"]}/.ssh"
			File.open("#{ENV["HOME"]}/.ssh/known_hosts", "a") do |f|
				f.print "#{dns_name} #{ssh_host_key}\n"
				f.print "#{public_ip} #{ssh_host_key}\n"
			end

			# wait for the volume
			unless image_root_device_type == "ebs"
				print "waiting for volume"
				while true
					print "."
					ret = ec2.describe_volumes({
						:volume_id => [ volume_id ],
					})
					volume_status = ret.volumeSet.item[0].status
					break if volume_status == "available"
					sleep 5
				end
				print "\n"
			end

			# attach volume
			unless image_root_device_type == "ebs"
				puts "attaching volume"
				ret = ec2.attach_volume({
					:volume_id => volume_id,
					:instance_id => instance_id,
					:device => "/dev/sdf",
				})
			end

			# wait for ssh
			print "waiting for ssh"
			start_time = Time.now
			until ret = system(
				Mandar.shell_quote(%W[
					ssh
					-o ConnectTimeout=5
					-o StrictHostKeyChecking=yes
					-i #{ssh_key_file.path}
					root@#{dns_name}
					true
				]) + " >/dev/null 2>/dev/null")
				raise "Timed out waiting for ssh" unless (Time.now - start_time) < 5 * 60
				print "."
				sleep 5
			end
			print " (#{(Time.now - start_time).to_i} seconds)\n"

			# kill any existing ssh connection
			if File.exists?("#{WORK}/ssh/#{name}.pid")
				Process.kill 15, File.read("#{WORK}/ssh/#{name}.pid").to_i
				FileUtils.rm_rf "#{WORK}/ssh/#{name}.sock"
			end

			# install default-key as root's id_rsa
			# this gets replaced by deploy-base BUT without it deploy-base can't run
			# TODO this shouldn't happen, root shouldn't be sshing around like this
			puts "installing #{ssh_key_file.path} as /root/.ssh/id_rsa"
			ssh_cmd = Mandar.shell_quote %W[
				ssh
				-S none
				-i #{ssh_key_file.path}
			]
			system Mandar.shell_quote %W[
				rsync
				--rsh=#{ssh_cmd}
				#{ssh_key_file.path}
				root@#{dns_name}:/root/.ssh/id_rsa
			]

			# install ruby
			puts "installing ruby (if not already)"
			update_cmd = Mandar.shell_quote %W[ aptitude update ]
			upgrade_cmd = Mandar.shell_quote %W[ aptitude -y install ruby libxml-ruby rubygems ]
			full_cmd = "#{update_cmd}; #{upgrade_cmd}"
			system Mandar.shell_quote %W[
				ssh
				-S none
				-i #{ssh_key_file.path}
				root@#{dns_name}
				#{full_cmd}
			] or raise "Error"

			# delete stuff
			if created_ami
				ec2.deregister_image({
					:image_id => ami_id,
				})
			end
			if created_snapshot
				ec2.delete_snapshot({
					:snapshot_id => snapshot_id,
				})
			end

			puts "==============================================================================="
			puts "public hostname: #{dns_name}"
			puts "public ip: #{public_ip}"
			puts "private hostname: #{private_dns_name}"
			puts "private ip: #{private_ip}"
			puts "ssh key: #{ssh_host_key}"
			puts "instance id: #{instance_id}"
			puts "volume id: #{volume_id}"
			puts "==============================================================================="

			return {
				:public_hostname => dns_name,
				:public_ip => public_ip,
				:private_hostname => private_dns_name,
				:private_ip => private_ip,
				:ssh_host_key => ssh_host_key,
				:ec2_instance_id => instance_id,
				:ec2_volume_id => volume_id,
			}

		ensure
			temp_files.each { |f| f.unlink }

		end

	end

	def self.stop_instance(options)
		aws_account = options[:aws_account]
		instance_id = options[:instance_id]

		ec2 = Mandar::EC2.connect(aws_account[:name])

		ec2.stop_instances({
			:instance_id => instance_id
		})
	end

	def self.start_instance(options)
		aws_account = options[:aws_account]
		instance_id = options[:instance_id]
		ec2 = Mandar::EC2.connect(aws_account[:name])

		# start instance
		ec2.start_instances({
			:instance_id => instance_id
		})

		# wait for instance
		instance = wait_for_instance_state({
			:aws_account => aws_account,
			:instance_id => instance_id,
			:target_state => "running",
		})

		# return
		return {
			:public_hostname => instance.dnsName,
			:public_ip => instance.ipAddress,
			:private_hostname => instance.privateDnsName,
			:private_ip => instance.privateIpAddress,
		}
	end

	def self.wait_for_instance_state(options)
		aws_account = options[:aws_account]
		instance_id = options[:instance_id]
		target_state = options[:target_state]

		ec2 = Mandar::EC2.connect(aws_account[:name])

		# wait for instance
		print "waiting for instance #{instance_id} to enter state #{target_state}..."
		instance_state = ""
		start_time = Time.now
		until instance_state == target_state
			print "."
			sleep 5
			ret = ec2.describe_instances({
				:instance_id => instance_id,
			})
			instance = ret.reservationSet.item[0].instancesSet.item[0]
			instance_state = instance.instanceState.name
		end
		print " (#{(Time.now - start_time).to_i} seconds)\n"

		return instance
	end
end
