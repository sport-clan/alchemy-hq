module HQ
module MQ
class MqLogger

	attr_accessor :em_wrapper
	attr_accessor :mq_wrapper
	attr_accessor :deploy_id

	def initialize
		@sets = {}
		@history = []
	end

	def output content, stuff = {}, prefix = ""

		return \
			unless Tools::Logger.level_includes \
				:debug,
				content["level"]

		@em_wrapper.quick do

			publish({
				"type" => "deploy-log",
				"mode" => stuff[:mode],
				"content" => content,
			})

		end

	end

	def start

		@em_wrapper.quick do
			|return_proc|

			@deploy_progress_exchange =
				@mq_wrapper.channel.fanout  \
					"deploy-progress"

			@deploy_api_queue =
				@mq_wrapper.channel.queue \
					"deploy-api-#{@deploy_id}",
					:exclusive => true,
					:auto_delete => true

			@deploy_api_queue.subscribe do
				|message|
				handle_api JSON.parse(message)
			end

			publish({
				"type" => "deploy-start",
			})

		end

	end

	def stop

		@em_wrapper.quick do

			publish({
				"type" => "deploy-end",
			})

		end

	end

private

	def publish data

		data["deploy-id"] = @deploy_id
		data["sequence"] = @history.size

		@history << data

		data_json =
			MultiJson.dump data

		@deploy_progress_exchange.publish \
			data_json

	end

	def handle_api data

		case data["type"]

		when "send-deploy-progress"

			exchange =
				@mq_wrapper.channel.default_exchange

			@history.each do
				|item|

				item_json =
					MultiJson.dump item

				exchange.publish \
					item_json,
					:routing_key => data["return-address"]

			end

		else

			raise "Don't know how to handle #{data["type"]}"

		end

	end

end
end
end
