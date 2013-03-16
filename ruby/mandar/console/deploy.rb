module Mandar
module Console
class Deploy

	include Forms
	include Render
	include Utils

	def handle

		forbidden \
			unless can \
				[ "deployment", "deployment" ]

		if request_method == :post

			locks = locks_man.load
			my_change = locks_man.my_change locks, console_user, false

			if post_var("deploy") || post_var("deploy-mock")
				if my_change && my_change["state"] != "stage" && my_change["state"] != "done"
					raise "Invalid state"
				end
			end

			if post_var("rollback") || post_var("rollback-mock")
				if ! my_change || (my_change["state"] != "stage" && my_change["state"] != "done")
					raise "Invalid state"
				end
			end

			if post_var("unstage")
				if ! my_change || my_change["state"] != "stage"
					raise "Invalid state"
				end
			end

			if post_var("commit")
				if ! my_change || my_change["state"] != "done"
					raise "Invalid state"
				end
			end

			if post_var("deploy") || \
				post_var("deploy-mock") || \
				post_var("rollback") || \
				post_var("rollback-mock")

				# work out mock

				mock =
					post_var("deploy-mock") || \
					post_var("rollback-mock") \
						? true
						: false

				# work out mode

				mode =
					case

					when \
						(
							post_var("deploy") ||
							post_var("deploy-mock")
						) && my_change

						:staged

					when \
						post_var("rollback") ||
						post_var("rollback-mock")

						:rollback

					else

						:unstaged

					end

				# perform deploy

				deploy_id =
					stager.deploy \
						console_user,
						config.attributes["deploy-command"],
						config.attributes["deploy-profile"],
						mode,
						mock,
						true

			elsif post_var("unstage")

				stager.cancel console_user

			elsif post_var("commit")

				stager.commit console_user

			else

				raise "Invalid request"

			end

		end

		locks = locks_man.load
		my_change = locks_man.my_change locks, console_user, false

		page = {
			_type: :console_page,
			_title: "Deploy current configuration to all servers",

			_notices: {
				pending_changes: my_change && make_info({
					text: make_para_text("You have the following pending changes:"),
					list: {
						_type: :unordered_list,
						items: my_change["items"].sort { |a, b| a[0] <=> b[0] } \
							.map { |item_id, item| make_link "/type/edit/#{item_id}", item_id },
					},
				}),
			},
		}

		if deploy_id

			page[:output] = {
				_type: :div,
				_class: :deploy_output,
			}

			auth_data = {
				username: console_user,
				timestamp: Time.now.to_i,
			}

			require "openssl"

			web_socket_config =
				config.find_first("web-socket")

			security_config =
				config.find_first("security")

			auth_data[:hmac] =
				OpenSSL::HMAC.hexdigest \
					"sha1",
					security_config["secret"],
					JSON.dump(auth_data)

			auth_json =
				JSON.dump auth_data

			google_apis_url =
				"https://ajax.googleapis.com"

			jquery_url =
				"#{google_apis_url}/ajax/libs/jquery/1.9.1/jquery.min.js"

			page[:script] = "
				<script src=\"#{jquery_url}\"></script>
				<script src=\"/console.js\"></script>
				<script>
				  var deployDone = function () {
				    jQuery.ajax ('/deploy-buttons', {
				      cache: false,
				      success: function (data) {
				        stayAtBottom (function () {
				          $('.deploy-buttons').replaceWith (data);
				        });
				      },
				    });
				  };
				  $(function () {
				    deployProgress (
				      \"#{web_socket_config["prefix"]}\",
				      #{auth_json},
				      \"#{deploy_id}\",
				      \"detail\",
				      $(\".deploy-output\"),
				      deployDone);
				  });
				</script>
			"

		end

		if deploy_id

			page[:form] = {
				_type: :div,
				_class: :deploy_buttons,
			}

		else

			deploy_buttons =
				DeployButtons.new

			page[:form] =
				deploy_buttons.make_form

		end

		render page

	end

end
end
end
