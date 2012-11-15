require "hq/tools"

class HQ::Tools::Future

	def initialize thread_pool, *args, &block

		@mutex =
			Mutex.new

		@resource =
			ConditionVariable.new

		@result =
			nil

		thread_pool.schedule do

			begin

				@result =
					block.call *args

				@result_type =
					:return

			rescue => exception

				@result =
					exception

				@result_type =
					:exception

			ensure

				@mutex.synchronize do
					@resource.broadcast
				end

			end

		end

	end

	def get

		@mutex.synchronize do

			loop do

				case @result_type

					when :return

						return @result

					when :exception

						raise @result

					else

						@resource.wait \
							@mutex

				end

			end

		end

	end

end
