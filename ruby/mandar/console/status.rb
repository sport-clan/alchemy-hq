class Mandar::Console::Status

	include Mandar::Console::Render
	include Mandar::Console::Utils

	def handle

		locks = locks_man.load
		my_change = locks_man.my_change locks, console_user, false

		page = {
			_type: :console_page,
			_title: "View status of current deployments",
		}

		page[:form] = {
			_type: :form,
			_method: :post,
		}

		page[:changes] = {
			_type: :section,
			_heading: "Pending changes",
		}

		if locks["changes"].empty?
			page[:changes][:no_changes] = "
				<p>No changes being made at this time.</p>
			"
		end

		locks["changes"].each do |role, change|
			page[:changes][role] = {
				_type: :mandar_status_change,
				_change: change,
			}
		end

		render page

	end

	def render_type_mandar_status_change content

		render_check content, {
			change: {
				required: true,
			},
		}

		change = content[:_change]

		output = {
			_type: :section,
			_heading: "Role #{change["role"]}",
		}

		timestamps = {
			"timestamp" => "Created",
			"deploy-timestamp" => "Deploy started",
			"done-timestamp" => "Deploy completed",
			"rollback-timestamp" => "Rollback started",
			"rollback-done-timestamp" => "Rollback completed",
		}

		output[:state] = make_para_text "State: #{change["state"]}"

		timestamps.each do |key, label|
			next unless timestamp = change[key]
			output[key] = make_para_text "#{label}: #{to_ymd_hms timestamp}"
		end

		output[:items_label] = make_para_text "Items:"
		output[:items] = {
			_type: :unordered_list,
		}
		change["items"].each do |id, item|
			output[:items][id] = make_item({
				text: make_link("/type/edit/#{id}", id),
				link: make_text(" (#{item["action"]})"),
			})
		end

		render output
	end

end
