module Mandar::Support::Ubuntu

	Mandar::Deploy::Commands.register self, :initctl_auto

	def self.initctl_auto service, new_running, restart_flag

		Mandar.debug "checking status of #{service}"

		if $mock && ! File.exist?("/etc/init/#{service}.conf")

			old_running = false
			restart = false

		else

			status_args = [
				"initctl",
				"status",
				service,
			]

			status_ret =
				Mandar::Support::Core.shell_real \
					Mandar.shell_quote(status_args),
					:log => false

			raise "initctl status #{service} returned #{status_ret[:status]}" \
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
				restart_flag \
					&& Mandar::Deploy::Flag.check(restart_flag)

		end


		if old_running && new_running && restart

			Mandar.notice "restarting #{service}"

			unless $mock

				# stop it

				stop_args = [
					"initctl",
					"stop",
					service
				]

				Mandar::Support::Core.shell \
					Mandar.shell_quote(stop_args)

				# wait for it to stop

				# TODO wait for status to show stop/waiting properly

				sleep 1

				# start it

				start_args = [
					"initctl",
					"start",
					service
				]

				Mandar::Support::Core.shell \
					Mandar.shell_quote(start_args)

			end

		elsif ! old_running && new_running

			Mandar.notice "starting #{service}"

			unless $mock

				start_args = [
					"initctl",
					"start",
					service
				]

				Mandar::Support::Core.shell \
					Mandar.shell_quote(start_args) \

			end

		elsif old_running && ! new_running

			Mandar.notice "stopping #{service}"

			unless $mock

				stop_args = [
					"initctl",
					"stop",
					service
				]

				Mandar::Support::Core.shell \
					Mandar.shell_quote(stop_args)

			end

		end

		if restart_flag
			Mandar::Deploy::Flag.clear restart_flag
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
