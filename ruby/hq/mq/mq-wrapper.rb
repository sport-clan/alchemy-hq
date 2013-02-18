require "hq/mq"

module HQ
module MQ
class MqWrapper

	attr_accessor :host
	attr_accessor :port
	attr_accessor :vhost
	attr_accessor :username
	attr_accessor :password

	attr_reader :connection
	attr_reader :channel

	def start

		@em_fiber =
			Fiber.new { startup }

		@em_fiber.resume

	end

	def startup

		require "amqp"
		require "eventmachine"

		EventMachine.run do

			@connection =
				AMQP.connect \
					:host => @host,
					:port => @port,
					:vhost => @vhost,
					:username => @username,
					:password => @password

			@channel =
				AMQP::Channel.new \
					@connection

			Fiber.yield

		end

	end

	def continue

		EventMachine.add_timer 0 do
			Fiber.yield
		end

		@em_fiber.resume

	end

	def schedule *args, &proc

		EventMachine.add_timer 0 do

			return_proc =
				Proc.new do
					|return_value|
					Fiber.yield return_value
				end

			proc.call return_proc

		end

		return @em_fiber.resume

	end

	def stop

		EventMachine.add_timer 0 do

			@channel.close do
				@connection.disconnect do
					EventMachine.stop_event_loop
				end
			end

		end

		@em_fiber.resume

	end

end
end
end
