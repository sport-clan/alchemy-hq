module Mandar::Support::Service

	def self.service(name, command)
		Tempfile.open "mandar" do |tmp|
			return false if command == "status" && ! File.exists?("/etc/init.d/#{name}")

			cmd = "service #{name} #{command} >#{tmp.path}"

			ret = system cmd

			return ret if command == "status"
			return true if ret
			system "cat #{tmp.path}"
			raise "Error #{command}ing #{name}"
		end
	end

	Mandar::Deploy::Commands.register self, :reload
	Mandar::Deploy::Commands.register self, :restart
	Mandar::Deploy::Commands.register self, :start
	Mandar::Deploy::Commands.register self, :stop

	def self.command_reload(reload_elem)
		reload_service = reload_elem.attributes["service"]
		reload_check_status = reload_elem.attributes["check-status"]
		if reload_check_status == "no" or service reload_service, "status"
			Mandar.notice "reloading #{reload_service}"
			service reload_service, "reload" unless $mock
		else
			Mandar.notice "starting #{reload_service}"
			service reload_service, "start" unless $mock
		end
	end

	def self.command_restart(restart_elem)
		restart_service = restart_elem.attributes["service"]
		restart_check_status = restart_elem.attributes["check-status"]
		if restart_check_status == "no" or service restart_service, "status"
			Mandar.notice "restarting #{restart_service}"
			service restart_service, "restart" unless $mock
		else
			Mandar.notice "starting #{restart_service}"
			service restart_service, "start" unless $mock
		end
	end

	def self.command_start start_elem

		start_service = start_elem.attributes["service"]
		start_stopped = start_elem.attributes["stopped"] == "yes"

		return command_stop start_elem if start_stopped

		return if service start_service, "status"

		Mandar.notice "starting #{start_service}"
		service start_service, "start" unless $mock
	end

	def self.command_stop(stop_elem)
		stop_service = stop_elem.attributes["service"]
		if service stop_service, "status"
			Mandar.notice "stoping #{stop_service}"
			service stop_service, "stop" unless $mock
		end
	end

end
