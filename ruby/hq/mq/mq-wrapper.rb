module HQ
module MQ
class MqWrapper

	attr_accessor :em_wrapper

	attr_accessor :host
	attr_accessor :port
	attr_accessor :vhost
	attr_accessor :username
	attr_accessor :password

	attr_reader :connection
	attr_reader :channel

	def start

		require "amqp"

		@em_wrapper.slow do
			|return_proc|

			@connection =
				AMQP.connect \
					:host => @host,
					:port => @port,
					:vhost => @vhost,
					:username => @username,
					:password => @password \
			do

				@channel =
					AMQP::Channel.new \
						@connection \
					do

						return_proc.call

					end

			end

		end

	end

	def stop

		@em_wrapper.slow do
			|return_proc|

			@channel.close do
				@connection.disconnect do
					return_proc.call
				end
			end

		end

	end

end
end
end
