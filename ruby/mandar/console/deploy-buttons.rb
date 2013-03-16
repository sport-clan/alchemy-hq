class Mandar::Console::DeployButtons

	include Mandar::Console::Forms
	include Mandar::Console::Render
	include Mandar::Console::Utils

	def handle
		render make_form
	end

	def make_form

		forbidden \
			unless can \
				[ "deployment", "deployment" ]

		locks = locks_man.load
		my_change = locks_man.my_change locks, console_user, false

		form = {
			_type: :form,
			_method: :post,
		}

		change_in_progress = nil
		locks["changes"].each do |role, change|
			next if change["state"] == "stage"
			change_in_progress = change
		end

		if change_in_progress && change_in_progress["role"] != console_user

			form[:deploying] = make_para_text \
				"Cannot deploy now as #{change_in_progress["role"]} has uncommitted changes."

			if my_change && my_change["state"] == "stage"

				form[:unstage] = {
					_type: :submit,
					_name: "unstage",
					_label: "cancel",
				}

			end

		elsif ! my_change

			form[:deploy] = {
				_type: :submit,
				_name: "deploy",
				_label: "deploy",
			}

			form[:deploy_mock] = {
				_type: :submit,
				_name: "deploy-mock",
				_label: "deploy (mock)",
			}

		elsif my_change["state"] == "stage"

			form[:deploy] = {
				_type: :submit,
				_name: "deploy",
				_label: "deploy",
			}

			form[:deploy_mock] = {
				_type: :submit,
				_name: "deploy-mock",
				_label: "deploy (mock)",
			}

			if my_change["rollback_timestamp"]

				form[:rollback] = {
					_type: :submit,
					_name: "rollback",
					_label: "re-rollback",
				}

				form[:rollback_mock] = {
					_type: :submit,
					_name: "rollback-mock",
					_label: "re-rollback (mock)",
				}

			end

			form[:unstage] = {
				_type: :submit,
				_name: "unstage",
				_label: "cancel",
			}

		elsif my_change["state"] == "done"

			form[:deploy] = {
				_type: :submit,
				_name: "deploy",
				_label: "re-deploy",
			}

			form[:deploy_mock] = {
				_type: :submit,
				_name: "deploy-mock",
				_label: "re-deploy (mock)",
			}

			form[:rollbacl] = {
				_type: :submit,
				_name: "rollback",
				_label: "rollback",
			}

			form[:rollback_mock] = {
				_type: :submit,
				_name: "rollback-mock",
				_label: "rollback (mock)",
			}

			form[:commit] = {
				_type: :submit,
				_name: "commit",
				_label: "commit",
			}

		elsif my_change["state"] == "deploy"

			form[:deploying] = make_para_text "Deploy in progress..."

		elsif my_change["state"] == "rollback"

			form[:deploying] = make_para_text "Rollback in progress..."

		else

			raise "Invalid state: #{my_change["state"]}"

		end

		return form

	end

end
