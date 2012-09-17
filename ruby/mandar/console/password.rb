class Mandar::Console::Password

	include Mandar::Console::Forms
	include Mandar::Console::Render
	include Mandar::Console::Table
	include Mandar::Console::Utils

	def handle

		# normal users can only change their own password
		if ! is_admin && (get_var("name") != console_user || get_var("search") != "search")
			redirect "/password?search=search&name=#{u console_user}"
		end

		page = {
			_type: :console_page,
			_title: "Change password",
		}

		# get locks
		locks = locks_man.load
		my_change = locks_man.my_change locks, console_user, false

		# can't change password if we have pending changes
		if my_change
			page[:warn] = make_para "Warning: Changing passwords will fail because you have other changes pending."
		end

		if get_var("search")

			# query db for all roles
			type_elem = config.find_first("schema [@name = 'role']")
			result = db.view_key "root", "by_type", "role"

			# extract array of row values
			values = result["rows"].map { |row| row["value"] }

			# find all matches using substring search
			matching_values = values.select do |value|
				! %W[ name email ].find do |field|
					case
						when get_vars[field].to_s.empty? then nil
						when value[field].to_s.empty? then :fail
						when ! value[field].include?(get_vars[field]) then :fail
					end
				end
			end

			# find one exact match using full string comparison
			matching_value = values.select do |value|
				case
					when ! get_var("name").to_s.empty? && value["name"] != get_var("name") then false
					when ! get_var("email").to_s.empty? && value["email"] != get_var("email") then false
					when ! get_var("name") && ! get_var("email") then false
					else true
				end
			end
			raise "assertion failed" unless matching_value.length <= 1

			# change password
			if post_var("change-password")

				# can't change password if we have pending changes
				raise "can't change passwords while other changes are pending" if my_change

				# sanity check
				raise "user not found" if matching_value.length != 1

				value = matching_value.first
				password = post_var("password")

				# create unix crypt version of password
				salt_chars = [ (?a..?z), (?A..?Z), (?0..?9), [ ?., ?/ ] ].map { |x| x.to_a }.flatten
				salt = (0...16).map { salt_chars[rand salt_chars.length] }.join("")
				value["password-crypt"] = password.crypt "$6$#{salt}$"

				# create sha version of password
				value["password-sha"] = Digest::SHA1.hexdigest password

				# save record
				stager.update value, console_user
				stager.commit console_user, true

				# deploy changes
				stager.deploy console_user, config.attributes["deploy-command"], config.attributes["deploy-profile"]

				page[:password_changed] = "
					<p>Password changed. This may take several seconds to take effect.</p>
				"
			end

			if is_admin && matching_values.empty?
				page[:no_results] = "
					<p>Sorry, no matching results could be found</p>
				"
			end

			if matching_value.length == 1
				value = matching_value.first

				page[:change_password] = {
					_type: :section,
					_heading: "Change password for #{value["name"]}"
				}

				page[:change_password][:form] = {
					_type: :form,
					_method: :post,
					fields: {
						_type: :fields,
						password: make_text_field("password", "new password"),
						controls: make_generic_field("", 0, {
							submit: make_submit("change-password", "change password"),
						}),
					},
				}

			end

			no_results = matching_values.length == 1 && matching_value.length == 1
			if is_admin && ! matching_values.empty? && ! no_results

				page[:search_results] = {
					_type: :section,
					_heading: "Search results",
				}

				page[:search_results][:data] =
					console_table \
						type_elem,
						matching_values,
						false,
						{ "change password" => lambda { |value|
							"/password?search=search&name=#{u value["name"]}"
						} }

			end
		end

		if is_admin

			page[:search] = {
				_type: :section,
				_heading: "Search users",
			}

			page[:search][:form] = {
				_type: :form,
				_method: :get,
				info: "<p>Enter either name or email to search users.</p>",
				fields: {
					_type: :fields,
					name: make_text_field("name", "name", get_var("name")),
					email: make_text_field("email", "email", get_var("email")),
					controls: make_generic_field("", 0, {
						submit: make_submit("search", "search"),
					}),
				},
			}
		end

		render page

	end
end
