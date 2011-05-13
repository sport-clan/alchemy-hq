module Mandar::Deploy::Control

	def self.deploy(service_elems)

		services = Hash[service_elems.map { |e| [ e.attributes["name"], e ] }]

		# fetch service and dependency info
		service_deps = {}
		services.values.each do |service|
			service_name = service.attributes["name"]
			service_deps[service_name] ||= []
		end
		services.values.each do |service|
			service_name = service.attributes["name"]
			service_after = service.attributes["after"]
			service_before = service.attributes["before"]
			if service_after
				service_after.to_s.strip.split(/\s+/).each do |s|
					throw "No such service #{s} mentioned in after list for #{service_name}" unless service_deps[s]
					service_deps[service_name] << s
				end
			end
			if service_before
				service_before.to_s.strip.split(/\s+/).each do |s|
					throw "No such service #{s} mentioned in before list for #{service_name}" unless service_deps[s]
					service_deps[s] << service_name
				end
			end
		end

		# sort services according to dependencies
		service_order = []
		while service_deps.length > 0
			progress = false
			service_deps.each do |service, deps|
				next if (deps - service_deps.keys).length < deps.length
				service_order << service
				service_deps.delete service
				progress = true
			end
			throw "Unable to resolve service dependencies" unless progress
		end

		# invoke services in specified order
		service_order.each do |service_name|
			Mandar.debug "deploying #{service_name}"
			a = Time.now.to_f
			begin
				Mandar::Deploy::Commands.perform(services[service_name])
			rescue => e
				Mandar.error "error during deployment of #{service_name}"
				Mandar.error e.inspect
				Mandar.error e.backtrace
				exit 1
			end
			b = Time.now.to_f
			Mandar.trace "deployed #{service_name} in #{((b-a)*1000).to_i}"
		end
	end
end
