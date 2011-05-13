module Mandar::EC2::SecurityGroups

	Mandar::Deploy::Commands.register self, :ec2_security_group

	LOCK = Mutex.new
	LOCKS = {}

	def self.lock(name)
		LOCK.synchronize do
			return LOCKS[name] ||= Mutex.new
		end
	end

	def self.command_ec2_security_group(group_elem)

		group_account = group_elem.attributes["account"]
		group_name = group_elem.attributes["name"]
		group_description = group_elem.attributes["description"]

		if $no_database
			Mandar.debug "Skipping <ec2-security-group account=\"%s\" name=\"%s\">" %
				[ group_account, group_name ]
			return
		end

		rules = {}
		group_elem.find("*").each do |elem0|
			case elem0.name

			when "allow"
				allow_elem = elem0

				allow_port = allow_elem.attributes["port"]
				allow_protocol = allow_elem.attributes["protocol"]
				allow_source = allow_elem.attributes["source"]

				if allow_protocol == "icmp"
					allow_port_from = "-1"
					allow_port_to = "-1"
				elsif allow_port =~ /^([0-9]+)-([0-9]+)$/
					raise "Not implemented"
				elsif allow_port =~ /^([0-9]+)$/
					allow_port_from = $1
					allow_port_to = $1
				elsif allow_port == nil || allow_port == ""
					allow_port_from = "0"
					allow_port_to = "65535"
				else
					raise "Invalid allow port: #{allow_port}"
				end

				if allow_source =~ /^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\/([0-9]+)/
					allow_source = "#{$1}/#{$2}"
				elsif allow_source =~ /^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/
					allow_source = "#{$1}/32"
				elsif allow_source == nil || allow_source == ""
					allow_source = "0.0.0.0/0"
				elsif allow_source =~ /^([a-z][-a-z0-9]*)$/
					allow_source = "#{$1}"
				elsif allow_source =~ /^([a-z][-a-z0-9]*)\/([a-z][-a-z0-9]*)$/
					allow_source = "#{$1}/#{$2}"
				else
					raise "Invalid allow source: #{allow_source}"
				end

				key = {
					:protocol => allow_protocol,
					:from_port => allow_port_from,
					:to_port => allow_port_to,
					:source => allow_source,
				}
				rules[key] = true

			else
				raise "Unexpected element #{elem0.name}"
			end
		end

		update_security_group group_account.to_s, group_name.to_s, group_description.to_s, rules
	end

	def self.init_security_groups(account_name)
		self.lock(account_name).synchronize do
			@security_groups ||= {}
			unless @security_groups[account_name]
				Mandar.debug "fetching security groups for #{account_name}"
				ec2 = Mandar::EC2.connect(account_name)
				@security_groups[account_name] = {}
				res = ec2.describe_security_groups
				res.securityGroupInfo.item.each do |res_sec_group|
					res_sec_group_name = res_sec_group.groupName
					@security_groups[account_name][res_sec_group_name] = {}
					next unless res_sec_group.ipPermissions
					res_sec_group.ipPermissions.item.each do |res_perm|
						key = {
							:protocol => res_perm.ipProtocol,
							:from_port => res_perm.fromPort,
							:to_port => res_perm.toPort,
						}
						if res_perm.groups
							res_perm.groups.item.each do |res_perm_group|
								temp_key = key.clone
								temp_key[:source] = res_perm_group.groupName
								@security_groups[account_name][res_sec_group_name][temp_key] = true
							end
						end
						if res_perm.ipRanges
							res_perm.ipRanges.item.each do |res_perm_range|
								temp_key = key.clone
								temp_key[:source] = res_perm_range.cidrIp
								@security_groups[account_name][res_sec_group_name][temp_key] = true
							end
						end
					end
				end
			end
		end
	end

	def self.rule_port_str(rule)
		if rule[:from_port] == rule[:to_port]
			return rule[:from_port]
		elsif rule[:from_port] == "-1" && rule[:to_port] == "-1"
			return "-"
		elsif rule[:from_port] == rule[:to_port]
			return rule[:from_port]
		elsif rule[:from_port] == "0" && rule[:to_port] == "65535"
			return "*"
		else
			return "#{rule[:from_port]}/#{rule[:to_port]}"
		end
	end

	def self.update_security_group(account_name, group_name, group_description, new_rules)

		# fetch data from amazon
		init_security_groups account_name

		# setup ec2 connection
		ec2 = Mandar::EC2.connect(account_name)

		# make sure security group exists
		unless @security_groups[account_name][group_name]
			Mandar.notice "creating security group #{account_name}/#{group_name}"
			unless $mock
				result = ec2.create_security_group({
					:group_name => group_name,
					:group_description => group_description,
				})
				raise "Amazon error" unless result.return == "true"
			end
			@security_groups[account_name][group_name] = {}
		end

		# see if anything needs changing
		old_rules = @security_groups[account_name][group_name]
		return if old_rules == new_rules

		# find rules to add and remove
		changes = []
		(new_rules.keys - old_rules.keys).each do |rule|
			changes << { :type => :add, :rule => rule }
		end
		(old_rules.keys - new_rules.keys).each do |rule|
			changes << { :type => :remove, :rule => rule }
		end

		# process changes
		changes.each do |change|
			type = change[:type]
			rule = change[:rule]

			# output a message
			info = "%s: %s port %s from %s" % [
				"#{account_name}/#{group_name}",
				rule[:protocol],
				rule_port_str(rule),
				rule[:source],
			]
			Mandar.notice "#{type} firewall rule #{info}"

			# prepare amazon request
			options = {
				:group_name => group_name,
				:ip_protocol => rule[:protocol],
				:from_port => rule[:from_port],
				:to_port => rule[:to_port],
			}
			if rule[:source] =~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+/
				options[:cidr_ip] = rule[:source]
			elsif rule[:source] =~ /^[a-z]+(?:-[a-z]+)*$/
				options[:source_security_group_name] = rule[:source]
			else
				raise "invalid rule source: #{rule[:source]}"
			end

			# perform amazon request
			unless $mock
				case type
				when :add
					result = ec2.authorize_security_group_ingress options
				when :remove
					result = ec2.revoke_security_group_ingress options
				end
				raise "Amazon error" unless result.return == "true"
			end

		end

		# update state
		@security_groups[account_name][group_name] = new_rules
	end

end
