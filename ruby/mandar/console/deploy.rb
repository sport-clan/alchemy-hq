class Mandar::Console::Deploy

	include Mandar::Console::Forms
	include Mandar::Console::Render
	include Mandar::Console::Utils

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

			if post_var("deploy") || post_var("deploy-mock") || post_var("rollback") || post_var("rollback-mock")

				# work out mock
				mock = post_var("deploy-mock") || post_var("rollback-mock") ? true : false

				# work out mode
				mode = case
					when (post_var("deploy") || post_var("deploy-mock")) && my_change then :staged
					when post_var("rollback") || post_var("rollback-mock") then :rollback
					else :unstaged
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

			page[:script] = "
				<script src=\"https://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js\"></script>
				<script src=\"/console.js\"></script>
				<script>
				  var deployDone = function () {
				    stayAtBottom (function () {
				      $(\"form\").show ()
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

		page[:form] = {
			_type: :form,
			_method: :post,
			_style: {},
		}

		if deploy_id
			page[:form][:_style]["display"] = "none"
		end

		change_in_progress = nil
		locks["changes"].each do |role, change|
			next if change["state"] == "stage"
			change_in_progress = change
		end

		if change_in_progress && change_in_progress["role"] != console_user

			page[:form][:deploying] = make_para_text \
				"Cannot deploy now as #{change_in_progress["role"]} has uncommitted changes."

			if my_change && my_change["state"] == "stage"

				page[:form][:unstage] = {
					_type: :submit,
					_name: "unstage",
					_label: "cancel",
				}

			end

		elsif ! my_change

			page[:form][:deploy] = {
				_type: :submit,
				_name: "deploy",
				_label: "deploy",
			}

			page[:form][:deploy_mock] = {
				_type: :submit,
				_name: "deploy-mock",
				_label: "deploy (mock)",
			}

		elsif my_change["state"] == "stage"

			page[:form][:deploy] = {
				_type: :submit,
				_name: "deploy",
				_label: "deploy",
			}

			page[:form][:deploy_mock] = {
				_type: :submit,
				_name: "deploy-mock",
				_label: "deploy (mock)",
			}

			if my_change["rollback_timestamp"]

				page[:form][:rollback] = {
					_type: :submit,
					_name: "rollback",
					_label: "re-rollback",
				}

				page[:form][:rollback_mock] = {
					_type: :submit,
					_name: "rollback-mock",
					_label: "re-rollback (mock)",
				}

			end

			page[:form][:unstage] = {
				_type: :submit,
				_name: "unstage",
				_label: "cancel",
			}

		elsif my_change["state"] == "done"

			page[:form][:deploy] = {
				_type: :submit,
				_name: "deploy",
				_label: "re-deploy",
			}

			page[:form][:deploy_mock] = {
				_type: :submit,
				_name: "deploy-mock",
				_label: "re-deploy (mock)",
			}

			page[:form][:rollbacl] = {
				_type: :submit,
				_name: "rollback",
				_label: "rollback",
			}

			page[:form][:rollback_mock] = {
				_type: :submit,
				_name: "rollback-mock",
				_label: "rollback (mock)",
			}

			page[:form][:commit] = {
				_type: :submit,
				_name: "commit",
				_label: "commit",
			}

		elsif my_change["state"] == "deploy"

			page[:form][:deploying] = make_para_text "Deploy in progress..."

		elsif my_change["state"] == "rollback"

			page[:form][:deploying] = make_para_text "Rollback in progress..."

		else

			raise "Invalid state: #{my_change["state"]}"

		end

		render page

	end

end
