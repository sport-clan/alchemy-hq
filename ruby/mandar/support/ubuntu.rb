module Mandar::Ubuntu

	Mandar::Deploy::Commands.register self, :initctl_auto

	def self.initctl_auto service, new_running, restart_flag

		Mandar.debug "checking status of #{service}"

		status_args = [
			"initctl",
			"status",
			service,
		]

		status_ret =
			Mandar::Support::Core.shell_real \
				Mandar.shell_quote(status_args)

		raise "Error" \
			unless status_ret[:status] == 0

		status_match =
			status_ret[:output][0] =~
				/^#{Regexp.quote service} (start|stop)\//

		raise "Error" \
			unless status_match

		old_running =
			case $1
				when "start" then true
				when "stop" then false
				else raise "Error"
			end

		restart =
			Mandar::Deploy::Flag.check restart_flag

		if old_running && restart

			Mandar.notice "restarting #{service}"

			restart_args = [
				"initctl",
				"restart",
				service
			]

			Mandar::Support::Core.shell \
				Mandar.shell_quote(restart_args)

		elsif ! old_running && new_running

			Mandar.notice "starting #{service}"

			start_args = [
				"initctl",
				"start",
				service
			]

			Mandar::Support::Core.shell \
				Mandar.shell_quote(start_args)

		elsif old_running && ! new_running

			Mandar.notice "stopping #{service}"

			stop_args = [
				"initctl",
				"stop",
				service
			]

			Mandar::Support::Core.shell \
				Mandar.shell_quote(stop_args)

		end

	end

	def self.command_initctl_auto auto_elem

		auto_service =
			auto_elem.attributes["service"]

		auto_running =
			case auto_elem.attributes["running"]
				when "yes" then true
				when "no" then false
				else raise "Error"
			end

		auto_restart_flag =
			auto_elem.attributes["restart-flag"]

		initctl_auto \
			auto_service,
			auto_running,
			auto_restart_flag

	end

end
