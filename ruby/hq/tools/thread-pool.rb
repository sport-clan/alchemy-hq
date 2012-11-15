require "hq/tools"

class HQ::Tools::ThreadPool

	def initialize
		@tasks = Queue.new
	end

	def worker_init
		return unless @init_hook
		@init_hook.call
	end

	def worker_run

		catch :exit do

			loop do
				task, args = @tasks.pop
				task.call *args
			end

		end

	end

	def worker_deinit
		return unless @deinit_hook
		@deinit_hook.call
	end

	def schedule *args, &block
		@tasks << [ block, args ]
	end

	def init_hook &block
		@init_hook = block
	end

	def deinit_hook &block
		@deinit_hook = block
	end

	def start threads

		@threads =
			Array.new threads do

				Thread.new do
					worker_init
					worker_run
					worker_deinit
				end

			end

	end

	def stop

		@threads.size.times do
			schedule { throw :exit }
		end

		@threads.each do
			|thread|
			thread.join
		end

	end

end
