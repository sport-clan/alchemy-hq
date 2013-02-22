module HQ
module Engine
class UnlockCommand

	attr_accessor :hq

	def couch() hq.couch end
	def logger() hq.logger end

	def go command_name

		locks =
			couch.get "mandar-locks"

		if locks["deploy"]

			if locks["deploy"]["role"] == $deploy_role

				logger.warning "unlocking deployment for role " +
					"#{locks["deploy"]["role"]}"

				locks["deploy"] = nil

			else

				logger.error "not unlocking deployment for role " +
					"#{locks["deploy"]["role"]}"

			end

		end

		locks["changes"].each do
			|role, change|

			next if change["state"] == "stage"

			if role == $deploy_role

				logger.warning "unlocking changes in state " +
					"#{change["state"]} for role #{role}"

				change["state"] = "stage"

			else

				logger.warning "not unlocking changes in state " +
					"#{change["state"]} for role #{role}"

			end

		end

		couch.update locks

	end

end
end
end
