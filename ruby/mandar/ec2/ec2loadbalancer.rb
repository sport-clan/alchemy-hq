module Mandar::EC2::LoadBalancer

	Mandar::Deploy::Commands.register self, :ec2_load_balancer

	LOCK = Mutex.new

	def self.get_load_balancers account_name, region
		LOCK.synchronize do

			# use cached data if available
			@load_balancers ||= {}
			key = "#{account_name}/#{region}"
			return @load_balancers[key] if @load_balancers[key]

			# fetch data
			Mandar.debug "fetching load balancers for #{account_name} in #{region}"
			balancers = {}
			ec2 = connect account_name, region
			res = ec2.describe_load_balancers
			ret = {}
			res.root.find("
				a:DescribeLoadBalancersResult /
				a:LoadBalancerDescriptions /
				a:member
			").each do |balancer_elem|
				balancer = {
					:name => balancer_elem.find_first("string (a:LoadBalancerName)"),
					:instances => balancer_elem.find("a:Instances / a:member").to_a.map { |instance_elem|
						instance_elem.find_first "string (a:InstanceId)"
					}.sort,
					:zones => balancer_elem.find("a:AvailabilityZones / a:member").to_a.map { |zone_elem|
						zone_elem.find("string()")
					}.sort,
				}
				balancers[balancer[:name]] = balancer
			end

			# and return
			return @load_balancers[key] = balancers
		end
	end

	def self.command_ec2_load_balancer the_elem
		name = the_elem.attributes["name"]
		account_name = the_elem.attributes["account"]
		region = the_elem.attributes["region"]

		target_instance_ids = the_elem.find("instance").to_a.map { |instance_elem|
			instance_elem.attributes["id"]
		}.sort

		target_zones = the_elem.find("zone").to_a.map { |zone_elem|
			zone_elem.attributes["name"]
		}.sort

		balancers = get_load_balancers account_name, region
		balancer = balancers[name]
		unless balancer
			Mandar.warning "can't update instances for nonexistant load balancer #{name}"
			return
		end

		ec2 = connect account_name, region

		# add instances
		add_instance_ids = target_instance_ids - balancer[:instances]
		unless add_instance_ids.empty?
			Mandar.notice "registering instances #{add_instance_ids.join ","} with load balancer #{name}"
			unless $mock
				res = ec2.aws_invoke "RegisterInstancesWithLoadBalancer", {
					"LoadBalancerName" => name,
					"Instances" => {
						"member" => add_instance_ids.map { |instance_id|
							{ "InstanceId" => instance_id }
						},
					},
				}
				# TODO check response
			end
		end

		# remove instances
		remove_instance_ids = balancer[:instances] - target_instance_ids
		unless remove_instance_ids.empty?
			Mandar.notice "deregistering instances #{remove_instance_ids.join ","} with load balancer #{name}"
			unless $mock
				res = ec2.aws_invoke "DeregisterInstancesFromLoadBalancer", {
					"LoadBalancerName" => name,
					"Instances" => {
						"member" => remove_instance_ids.map { |instance_id|
							{ "InstanceId" => instance_id }
						},
					},
				}
				# TODO check response
			end
		end

		# enable zones
		enable_zones = target_zones - balancer[:zones]
		unless enable_zones.empty?
			Mandar.notice "enabling zones #{enable_zones.join ","} with load balancer #{name}"
			unless $mock
				res = ec2.aws_invoke "EnableAvailabilityZonesForLoadBalancer", {
					"LoadBalancerName" => name,
					"AvailabilityZones" => {
						"member" => enable_zones,
					},
				}
				# TODO check response
			end
		end

		# disable zones
		disable_zones = balancer[:zones] - target_zones
		unless disable_zones.empty?
			Mandar.notice "disabling zones #{disable_zones.join ","} with load balancer #{name}"
			unless $mock
				res = ec2.aws_invoke "DisableAvailabilityZonesForLoadBalancer", {
					"LoadBalancerName" => name,
					"AvailabilityZones" => {
						"member" => enable_zones,
					},
				}
				# TODO check response
			end
		end
	end

	def self.connect account_name, region
		endpoint = "elasticloadbalancing.#{region}.amazonaws.com"
		ec2 = Mandar::EC2.connect2 account_name, endpoint, "2010-07-01"
		return ec2
	end

end
