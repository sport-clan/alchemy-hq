require "hq/deploy"

module HQ
module Deploy
class MqLogger

	attr_accessor :mq_wrapper

	def publish data

		@mq_wrapper.schedule do
			|return_proc|

			data_json =
				MultiJson.dump data

			@mq_exchange.publish \
				data_json \

			return_proc.call

		end

	end

	def output content, stuff = {}, prefix = ""

		data = {
			"type" => "deploy-log",
			"mode" => stuff[:mode],
			"content" => content,
		}

		publish data

	end

	def start

		@mq_wrapper.schedule do
			|return_proc|

			@mq_exchange =
				@mq_wrapper.channel.fanout  \
					"deploy-progress" \
				do
					|exchange, declare_ok|
					return_proc.call
				end

		end

	end

end
end
end
