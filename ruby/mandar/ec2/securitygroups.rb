module Mandar::EC2::SecurityGroups

	Mandar::Deploy::Commands.register self, :ec2_security_groups

	def self.command_ec2_security_groups groups_elem

		group_account_name =
			groups_elem.attributes["account-name"]

		group_region_name =
			groups_elem.attributes["region-name"]

		group_access_key_id =
			groups_elem.attributes["access-key-id"]

		group_secret_access_key =
			groups_elem.attributes["secret-access-key"]

		group_endpoint =
			groups_elem.attributes["endpoint"]

		account = {
			:access_key_id => group_access_key_id,
			:secret_access_key => group_secret_access_key,
			:endpoint => group_endpoint,
		}

		ec2_client =
			Mandar::AWS.connect \
				group_endpoint,
				group_access_key_id,
				group_secret_access_key,
				"2012-05-01"

		account_name =
			"#{group_account_name}:#{group_region_name}"

		Mandar.debug "fetching security groups for #{account_name}"

		existing_groups_doc =
			ec2_client.describe_security_groups

		existing_groups =
			decode_amazon_response \
				existing_groups_doc

		target_groups =
			decode_groups_elem groups_elem

		target_groups.each do |group_name, target_group|

			existing_group =
				existing_groups[group_name]

			unless existing_group

				create_security_group \
					ec2_client,
					account_name,
					group_name,
					target_group[:description]

				existing_group = {}
			end

			update_security_group \
				ec2_client,
				account_name,
				group_name,
				existing_group,
				target_group[:rules]
		end
	end

	def self.create_security_group \
			ec2_client,
			account_name,
			group_name,
			group_description

		Mandar.notice "creating security group #{account_name}/#{group_name}"

		unless $mock

			result_doc =
				ec2_client.create_security_group \
					:group_name => group_name,
					:group_description => group_description

			query = "
				/ a:CreateSecurityGroupResponse
				/ a:return
			"

			result_doc.find_first(query).content == "true" \
				or raise "Amazon error"

		end
	end

	def self.decode_groups_elem groups_elem

		ret = {}

		groups_elem.find("*").each do |elem|

			case elem.name

				when "group"
					group_elem = elem

					group_name =
						group_elem.attributes["name"]

					group_description =
						group_elem.attributes["description"]

					ret[group_name] = {
						:name => group_name,
						:description => group_description,
						:rules => decode_group_elem(group_elem),
					}

				else
					raise "Unexpected element #{elem0name}"
			end
		end

		return ret
	end

	def self.decode_group_elem group_elem

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

		return rules
	end

	def self.init_security_groups \
			ec2_client,
			account_name

		self.lock(account_name).synchronize do

			@security_groups ||= {}

			unless @security_groups[account_name]

			end
		end
	end

	def self.decode_amazon_response groups_doc

		ret = {}

		query = "
			/ a:DescribeSecurityGroupsResponse
			/ a:securityGroupInfo
			/ a:item
		"

		groups_doc.find(query).each do |group_elem|

			group_name =
				group_elem.find_first("a:groupName").content

			ret[group_name] = {}

			query = "
				a:ipPermissions
				/ a:item
			"

			group_elem.find(query).each do |perm_elem|

				key = {

					:protocol => perm_elem \
						.find_first("a:ipProtocol").content,

					:from_port => perm_elem \
						.find_first("a:fromPort").content,

					:to_port => perm_elem \
						.find_first("a:toPort").content,
				}

				query = "
					a:groups
					/ a:item
				"

				perm_elem.find(query).each do |perm_group_elem|

					temp_key = key.clone

					temp_key[:source] =
						perm_group_elem \
							.find_first("a:groupName") \
							.content

					ret [group_name] [temp_key] = true

				end

				query = "
					a:ipRanges
					/ a:item
				"

				perm_elem.find(query).each do |perm_range_elem|

					temp_key = key.clone

					temp_key[:source] =
						perm_range_elem \
							.find_first("a:cidrIp") \
							.content

					ret [group_name] [temp_key] = true

				end
			end
		end

		return ret
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

	def self.update_security_group \
			ec2_client,
			account_name,
			group_name,
			old_rules,
			new_rules

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

				rule[:from_port] == "-1" \
					or raise "Error"

				rule[:to_port] == "-1" \
					or raise "Error"

				options[:source_security_group_name] = rule[:source]

			else
				raise "invalid rule source: #{rule[:source]}"
			end

			# perform amazon request

			unless $mock

				case type

					when :add

						result_doc =
							ec2_client.authorize_security_group_ingress \
								options

						query = "
							/ a:AuthorizeSecurityGroupIngressResponse
							/ a:return
						"

						result_doc.find_first(query).content == "true" \
							or raise "Amazon error"

					when :remove

						result =
							ec2_client.revoke_security_group_ingress \
								options

						query = "
							/ a:RevokeSecurityGroupIngressResponse
							/ a:return
						"

						result_doc.find_first(query).content == "true" \
							or raise "Amazon error"

				end

			end

		end

	end

end
