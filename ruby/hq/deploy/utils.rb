require "hq/tools/escape"

module HQ
module Deploy
module Utils

	include HQ::Tools::Escape

	def process_targets targets

		abstract =
			engine.abstract

		hosts = []

		for target in targets

			if target == "all"

				abstract["host"].each do |host_elem|
					hosts << host_elem.attributes["name"]
				end

				hosts << "local"

			elsif target == "local"

				hosts << "local"

			elsif abstract["host"].find_first("host[@name = #{esc_xp target}]")

				hosts <<= target

			elsif abstract["host"].find_first("host[@class = #{esc_xp target}]")

				abstract["host"].find("host[@class = #{esc_xp target}]").each do
					|host_elem|

					hosts <<= host_elem.attributes["name"]

				end

			elsif domain_elem = abstract["domain"].find_first("domain[@short-name = esc_xp target}]")

				domain_name = domain_elem.attributes["name"]

				abstract["host"].find("host[@domain='#{domain_name}']").each do
					|host_elem|

					hosts <<= host_elem.attributes["name"]

				end

			else

				raise "Unknown target #{target}"

			end

		end

		return hosts

	end

	def filter_hosts hosts, message, requested_hosts

		abstract =
			engine.abstract

		return hosts.select do |host|

			host_xp =
				esc_xp host

			query =
				"deploy-host [@name = #{host_xp}]"

			host_elem =
				abstract["deploy-host"].find_first query

			case

			when host == "local"

				true

			when ! host_elem

				logger.die "No such host #{host}"

			when ! host_elem.attributes["skip"].to_s.empty?

				message = "skipping host #{host} because " +
					"#{host_elem.attributes["skip"]}"

				if requested_hosts.include? host
					logger.warning message
				else
					logger.debug message
				end

				false

			when host_elem.attributes["no-deploy"] != "yes"

				message = "skipping host #{host} because it is " +
					"set to no-deploy"

				true

			when $force

				logger.warning "#{message} no-deploy host #{host}"

				true

			else

				logger.warning "skipping no-deploy host #{host}"

				false

			end

		end

	end

end
end
end
