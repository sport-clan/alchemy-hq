module HQ
module MQ
class MqLogger

	attr_accessor :em_wrapper
	attr_accessor :mq_wrapper

	def initialize
		@sets = {}
	end

	def publish data

		@em_wrapper.quick do

			data = data.clone

			@sets.each do
				|key, value|
				data[key] = value
			end

			data_json =
				MultiJson.dump data

			@mq_exchange.publish \
				data_json

		end

	end

	def output content, stuff = {}, prefix = ""

		return \
			unless Tools::Logger.level_includes \
				:debug,
				content["level"]

		data = {
			"type" => "deploy-log",
			"mode" => stuff[:mode],
			"content" => content,
		}

		publish data

	end

	def start

		@em_wrapper.slow do
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

	def set sets

		sets.each do
			|key, value|
			@sets[key] = value
		end

	end

	def unset keys

		keys.each do
			|key|
			@sets.delete key
		end

	end

end
end
end
