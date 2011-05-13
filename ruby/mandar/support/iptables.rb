module Mandar::Support::IPTables

	def self.invoke(args)
		cmd = "iptables #{Mandar.shell_quote args}"
		puts cmd
		system cmd
	end

	def self.activate(config_elem)

		# initialise chains
		config_elem.find("iptables-chain").each do |chain_elem|
			chain_name = chain_elem.attributes["name"]
			chain_policy = chain_elem.attributes["policy"]
			invoke %W[ --new-chain #{chain_name} ]
			invoke %W[ --policy #{chain_name} #{chain_policy} ] if chain_policy
			invoke %W[ --flush #{chain_name} ]
		end

		# fill chains
		config_elem.find("iptables-chain").each do |chain_elem|
			chain_name = chain_elem.attributes["name"]
			chain_elem.find("rule").each do |rule_elem|
				iptables_cmd = %W[ --append #{chain_name} ]
				if rule_protocol = rule_elem.attributes["protocol"]
					iptables_cmd += %W[ --protocol #{rule_protocol} ]
				end
				if rule_match = rule_elem.attributes["match"]
					iptables_cmd += %W[ --protocol #{rule_match} ]
				end
				rule_elem.attributes.each do |rule_attr|
					next if rule_attr.name == "protocol"
					next if rule_attr.name == "match"
					iptables_cmd += %W[ --#{rule_attr.name} #{rule_attr.value} ]
				end
				invoke iptables_cmd
			end
		end

	end

	def self.activate_file(config_file)
		doc = XML::Document.file config_file
		activate doc.root
	end

	def self.deactivate()
		[ "INPUT", "FORWARD", "OUTPUT" ].each do |chain_name|
			invoke %W[ --flush #{chain_name} ]
			invoke %W[ --policy #{chain_name} ACCEPT ]
		end
	end

end
