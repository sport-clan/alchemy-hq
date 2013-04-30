require "hq/tools/escape"

module Mandar
module Console
class DeployProgressHandler

	include HQ::Tools::Escape

	attr_accessor :app_ctx
	attr_accessor :web_socket

	def mq_wrapper() app_ctx[:mq_wrapper] end

	def initialize
		require "hq/logger/html-logger"
		require "hq/tools/random"
		@token = HQ::Tools::Random.lower_case
		@buffer = {}
	end

	def open handshake
	end

	def queue_message got_data

		return unless got_data["deploy-id"] == @deploy_id

		sequence = got_data["sequence"]

		if sequence < @next_sequence

			# old data, ignore it

		elsif sequence == @next_sequence

			# current data, display immediately

			real_queue_message got_data

		elsif sequence > @next_sequence

			# future data, buffer for later

			@buffer[sequence] = got_data

		end

		# output buffered data which is now current

		while @buffer[@next_sequence]

			buffered_item =
				@buffer.delete @next_sequence

			real_queue_message buffered_item

		end

	end

	def real_queue_message got_data

		@next_sequence += 1

		case got_data["type"]

		when "deploy-start"

			web_socket_send({
				"type" => "deploy-start",
				"deploy-id" => @deploy_id,
				"sequence" => got_data["sequence"],
			})

		when "deploy-log"

			@html_logger.out = StringIO.new

			@html_logger.output \
				got_data["content"],
				{ mode: got_data["mode"] }

			send_html =
				@html_logger.out.string

			return if send_html.empty?

			web_socket_send({
				"type" => "deploy-log",
				"deploy-id" => @deploy_id,
				"sequence" => got_data["sequence"],
				"html" => send_html,
			})

		when "deploy-end"

			web_socket_send({
				"type" => "deploy-end",
				"deploy-id" => @deploy_id,
				"sequence" => got_data["sequence"],
			})

			@deploy_progress_queue.unsubscribe

		end

	end

	def web_socket_send data
		json = JSON.dump data
		@web_socket.send json
	end

	def message data_json

		data = JSON.parse data_json

		case data["type"]

		when "start"
			start data

		else
			raise "Error #{data["type"]}"

		end
	end

	def start data

		@deploy_id = data["deploy-id"]
		@next_sequence = data["sequence"]
		@auth = data["auth"]

		# check auth is valid

		auth_hmac =
			OpenSSL::HMAC.hexdigest \
				"sha1",
				app_ctx[:config].find_first("security")["secret"],
				JSON.dump({
					username: @auth["username"],
					timestamp: @auth["timestamp"],
				})

		unless auth_hmac == @auth["hmac"]
			$stderr.puts "Authentication invalid"
			return
		end

		auth_age = Time.now.to_i - @auth["timestamp"]

		unless auth_age < 60 * 60
			$stderr.puts "Authentication expired"
			return
		end

		puts "AUTH OK (username=#{@auth["username"]}, age=#{auth_age})"

		# check permissions

		perms = [
			[ "super", "super" ],
			[ "deployment", "deployment" ],
		]

		valid_perm =
			perms.find do
				|type, subject|

				perms_xpath = "
					permission [
						@type = #{esc_xp type}
						and @subject = #{esc_xp subject}
						and @allow = 'yes'
					]
				"

				role_members_xpath = "
					role-member [
						@member = #{esc_xp @auth["username"]}
					]
				"

				app_ctx[:config].find "
					#{perms_xpath}/@role = #{role_members_xpath}/@role
				"

			end

		unless valid_perm
			$stderr.puts "Not authorized"
			return
		end

		# create logger

		@html_logger = HQ::Logger::HtmlLogger.new
		@html_logger.level = data["level"].to_sym

		# monitor deploy progress

		@deploy_progress_queue =
			AMQP::Queue.new \
				mq_wrapper.channel,
				"",
				:auto_delete => true

		@deploy_progress_queue.bind \
			mq_wrapper.channel.fanout \
				"deploy-progress"

		@deploy_progress_queue.subscribe do
			|data_json|
			data = MultiJson.load data_json
			queue_message data
		end

		# api queue

		@console_api_queue =
			AMQP::Queue.new \
				mq_wrapper.channel,
				"console-api-#{@token}",
				:auto_delete => true

		@console_api_queue.subscribe do
			|data_json|
			data = MultiJson.load data_json
			queue_message data
		end

		# request deploy progress

		data = {
			"type" => "send-deploy-progress",
			"return-address" => "console-api-#{@token}",
		}

		mq_wrapper.channel.default_exchange.publish \
			JSON.dump(data),
			:routing_key => "deploy-api-#{@deploy_id}"

	end

	def error error
		raise "Deploy progress error: #{error}"
	end

	def close
	end

end
end
end
