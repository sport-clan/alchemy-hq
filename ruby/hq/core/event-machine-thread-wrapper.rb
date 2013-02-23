module HQ
module Core
class EventMachineThreadWrapper

	def initialize
		@state = :new
	end

	def start

		raise "Error" unless @state == :new
		@state = :starting

		require "thread"

		@event_machine_thread =
			Thread.new \
		do
			startup
		end

		@state = :started

	end

	def startup

		require "eventmachine"

		begin

			EventMachine.run do

				EventMachine.error_handler do
					|exception|

					$stderr.puts \
						"Unhandled exception in reactor loop",
						exception.message,
						*exception.backtrace

					@state = :error

					EventMachine.stop_event_loop

				end

			end

		rescue => e

			STDOUT.puts [
				"EventMachine exited abnormally",
				e.message,
				*e.backtrace,
			]

			STDOUT.flush

			@state = :error

		end

	end

	def quick *args, &proc

		raise "Error" unless @state == :started

		EventMachine.next_tick do
			proc.call *args
		end

	end

	def slow *args, &proc

		raise "Error" unless @state == :started

		calling_thread = Thread.current
		mutex = Mutex.new
		task_complete = false
		return_value = nil

		# run task in eventmachine thread

		EventMachine.next_tick do

			# return proc signals the calling thread on completion

			return_proc = proc do
				|ret|

				mutex.synchronize do
					task_complete = true
					return_value = ret
					calling_thread.wakeup
				end

			end

			proc.call *args, return_proc

		end

		# wait for it to finish

		loop do

			mutex.synchronize do
				return return_value \
					if task_complete
			end

			Thread.stop

		end

	end

	def stop

		raise "Error" unless @state == :started
		@state = :stopping

		EventMachine.stop_event_loop

		@state = :stopped

	end

end
end
end
