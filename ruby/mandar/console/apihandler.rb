class Mandar::Console::ApiHandler

	include Mandar::Console::Utils

	def handle path

		case path

		when /^\/data((?:\/[^\/]+)*)$/
			# TODO
			not_found

		when /^\/stager\/data((?:\/[^\/]+)*)$/
			handle_data true, $1

		when /^\/stager\/cancel$/
			method_not_allowed unless request_method == :post
			stager.cancel console_user

			# output confirmation
			set_content_type "application/json"
			console_print JSON.dump({})

		when /^\/stager\/commit$/
			method_not_allowed unless request_method == :post
			stager.commit console_user

			# output confirmation
			set_content_type "application/json"
			console_print JSON.dump({})

		when /^\/stager\/(deploy|rollback)$/
			method_not_allowed unless request_method == :post
			must([ "deployment", "deployment" ])

			locks = locks_man.load
			my_change = locks_man.my_change locks, console_user, false
			conflict unless my_change
			conflict unless [ "stage", "done" ].include? my_change["state"]

			# perform action
			ret = stager.deploy(
				console_user,
				config.attributes["deploy-command"],
				config.attributes["deploy-profile"],
				$1 == "deploy" ? :staged : :rollback, false, false)
			resp.status = ret[:status] == 0 ? 200 : 500

			# output confirmation
			set_content_type "application/json"
			console_print JSON.dump({})

		else
			not_found

		end

	end

	def handle_data use_stager, path
		if path == ""

			# list of types
			set_content_type "application/json"
			schema_names = []
			config.find("schema").each do |schema_elem|
				schema_name = schema_elem.attributes["name"]
				next unless can([ "record-type", schema_name ])
				schema_names << schema_name
			end
			schema_names.sort!
			set_content_type "application/json"
			console_print JSON.dump schema_names

		else

			# split path
			parts = path[1..-1].split("/")
			type_name = parts.shift

			# look up type
			schema_elem = config.find_first("schema [@name = #{xp type_name}]")
			not_found unless schema_elem

			# get ids from type
			ids = []
			schema_elem.find("id/*").each do |id_elem|
				ids << id_elem.attributes["name"]
			end
			not_found unless parts.size <= ids.size

			parts_provided = case parts.size
				when 0 then :none
				when ids.size then :full
				else :partial
			end
			method_not_allowed unless [
				[ :none, :get ],
				[ :none, :post ],
				[ :some, :get ],
				[ :full, :get ],
				[ :full, :put ],
				[ :full, :delete ],
			].include? [ parts_provided, request_method ]

			if request_method == :get && parts.size == ids.size

				# check permissions
				must([ "record-type", type_name ])

				# return record
				record = stager.get "#{type_name}/#{parts.join("/")}", console_user
				not_found unless record
				record.delete "mandar_type"
				record.delete "_id"
				set_content_type "application/json"
				console_print JSON.dump record

			elsif request_method == :get && parts.size < ids.size

				# check permissions
				must([ "record-type", type_name ])

				# get list of sub ids
				all_records = stager.get_all type_name, console_user
				sub_ids = {}
				records = all_records.select do |record|

					# make sure this record matches
					match = true
					parts.each_with_index do |part, i|
						id = ids[i]
						next if part == record[id].to_s
						match = false
						break
					end
					next unless match

					# make sure the next partial id is in our list
					sub_id = record[ids[parts.size]]
					sub_ids[sub_id] = true

				end

				# output sub ids
				set_content_type "application/json"
				console_print JSON.dump(sub_ids.keys.sort)

			elsif request_method == :put && parts.size == ids.size

				# check permissions
				must([ "record-type", type_name ])

				# parse body
				record = JSON.parse(req.body)

				# check id matches
				parts.each_with_index do |part, i|
					id = ids[i]
					next if part == record[id].to_s
					bad_request
				end

				# update record
				record["mandar_type"] = type_name
				record["_id"] = "#{type_name}/#{parts.join "/"}"
				stager.update record, console_user

				# output confirmation
				set_content_type "application/json"
				console_print JSON.dump({})

			elsif request_method == :post && parts.size == 0

				# check permissions
				must([ "record-type", type_name ])

				# parse body
				record = JSON.parse(req.body)

				# build id
				record["_id"] = type_name
				ids.each do |id|
					id_part = record[id]
					record["_id"] += "/#{id_part}"
				end

				# create record
				record["mandar_type"] = type_name
				stager.create record, console_user

				# output confirmation
				set_content_type "application/json"
				console_print JSON.dump({})

			elsif request_method == :delete && parts.size == ids.size

				# check permissions
				must([ "record-type", type_name ])

				# parse body
				record = JSON.parse(req.body)

				# check id matches
				parts.each_with_index do |part, i|
					id = ids[i]
					next if part == record[id].to_s
					bad_request
				end

				# update record
				record["mandar_type"] = type_name
				record["_id"] = "#{type_name}/#{parts.join "/"}"
				stager.delete record, console_user

				# output confirmation
				set_content_type "application/json"
				console_print JSON.dump({})

			else
				bad_request

			end

		end
	end

end
