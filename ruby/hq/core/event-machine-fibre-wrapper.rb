module HQ
module Core
class EventMachineFibreWrapper

	def start

		require "fiber"

		@main_fiber =
			Fiber.current

		@event_machine_fiber =
			Fiber.new { startup }

		@event_machine_fiber.resume

	end

	def startup

		require "eventmachine"

		begin

			EventMachine.run do
				Fiber.yield
			end

		rescue => e

			STDOUT.puts [
				"EventMachine exited abnormally",
				e.message,
				*e.backtrace,
			]
			STDOUT.flush
			exit 1

		end

	end

	def continue

		raise "Wrong fiber" \
			unless Fiber.current == @main_fiber

		EventMachine.next_tick do
			Fiber.yield
		end

		@event_machine_fiber.resume

	end

	def quick *args, &proc

		if Fiber.current == @main_fiber

			EventMachine.next_tick do
				proc.call
				Fiber.yield
			end

			@event_machine_fiber.resume

		elsif Fiber.current == @event_machine_fiber

			proc.call

		else

			raise "Wrong fiber"

		end


	end

	def slow *args, &proc

		raise "Wrong fiber" \
			unless Fiber.current == @main_fiber

		EventMachine.next_tick do

			return_proc =
				Proc.new do
					Fiber.yield
				end

			proc.call return_proc

		end

		@event_machine_fiber.resume

	end

	def stop

		raise "Wrong fiber" \
			unless Fiber.current == @main_fiber

		EventMachine.stop_event_loop

		@event_machine_fiber.resume

	end

end
end
end
