module HQ
module Core
class ListenCommand

	attr_accessor :hq

	def em_wrapper() hq.em_wrapper end
	def logger() hq.logger end
	def mq_wrapper() hq.mq_wrapper end

	def go command_name

		mq_wrapper

		em_wrapper.slow do

			queue =
				AMQP::Queue.new \
					mq_wrapper.channel,
					"",
					:auto_delete => true \
				do
					|queue, declare_ok|

					queue.bind \
						mq_wrapper.channel.fanout \
							"deploy-progress"

					queue.subscribe do
						|data_json|

						data =
							MultiJson.load data_json

						case data["type"]

						when "deploy-log"
							logger.output \
								data["content"],
								data["mode"]

						else
							puts "got #{data["type"]}"

						end

					end

				end

		end

	end

end
end
end
