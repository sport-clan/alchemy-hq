class Mandar::Console::Stager

	include Mandar::Console::Data

	attr_accessor :db
	attr_accessor :entropy
	attr_accessor :locks_man

	def put record, action, my_role

		id = record["_id"]

		# sanity check arguments

		raise "Invalid record argument #{record.class}" \
			unless record.is_a? Hash

		raise "Invalid action argument #{action}" \
			unless [ :create, :update, :delete ].include? action

		# get locks and stuff

		locks =
			locks_man.load

		my_change =
			locks_man.my_change locks, my_role, true

		change_item =
			my_change["items"][id]

		# check for concurrent updates by the same role

		raise "Concurrent update" \
			if action == :create \
				&& change_item \
				&& change_item["action"] != "delete"

		raise "Concurrent update" \
			if action != :create \
				&& change_item \
				&& record["_rev"] != change_item["rev"]

		# check for concurrent updates by another role

		locks["changes"].each do |change_role, change|

			next if change_role == my_role

			raise "Record is locked by #{change_role}" \
				if change["items"].include? id

		end

		# make sure we aren't in the middle of a deployment

		case my_change["state"]

			when "stage"

			when "done"

			when "deploy"
				raise "Can't change records while a deploy is in progress"

			when "rollback"
				raise "Can't change records while a rollback is in progress"

			else
				raise "Internal error"

		end

		if change_item \
			&& action == :delete \
			&& change_item["action"] == "create"

			# delete change item (new record being deleted)

			my_change["items"].delete id

		else

			# create clean copy of record

			record_clone = data_clone record

			if change_item

				# update existing change item

				if change_item["record"]["_rev"]
					record_clone["_rev"] = change_item["record"]["_rev"]
				else
					record_clone.delete "_rev"
				end

				change_item["record"] = record_clone
				change_item["rev"] = entropy.rand_token

				change_item["action"] = "update" \
					if action == :create \
						&& change_item["action"] == "delete"

				change_item["action"] = "delete" \
					if action == :delete

			else

				# create new change item

				change_item = {
					"action" => action.to_s,
					"record" => record_clone,
					"rev" => entropy.rand_token,
				}

				my_change["items"][id] = change_item

			end
		end

		# and save it

		locks_man.save locks

	end

	def create record, my_role
		put record, :create, my_role
	end

	def update record, my_role
		put record, :update, my_role
	end

	def delete record, my_role
		put record, :delete, my_role
	end

	def get id, my_role

		# get locks and stuff
		locks = locks_man.load
		my_change = locks_man.my_change locks, my_role, false

		if my_change

			# return staged row
			change_item = my_change["items"][id]
			if change_item
				ret = data_clone change_item["record"]
				ret["_rev"] = change_item["rev"]
				return ret
			end

		end

		# return row from db

		row = db.get_nil "current/#{id}"
		if row
			value = row["value"]
			row["_id"] =~ /^current\/(.+)$/
			value["_id"] = $1
			value["_rev"] = row["_rev"]
			return value
		else
			return nil
		end

	end

	def get_all type_name, my_role

		# get locks and stuff

		locks = locks_man.load
		my_change = locks_man.my_change locks, my_role, false

		# perform query

		result =
			db.view_key "root", "by_type", type_name

		db_values =
			result["rows"].map do |row|
				value = row["value"]["value"]
				row["value"]["_id"] =~ /^current\/(.+)$/
				value["_id"] = $1
				value
			end

		return db_values \
			unless my_change

		# do update and delete
		values = []
		db_values.each do |value|
			item = my_change["items"][value["_id"]]
			if ! item
				values << value
			elsif item["action"] == "update"
				values << item["record"]
			elsif item["action"] == "delete"
				# do nothing
			end
		end

		# do create
		my_change["items"].each do |id, item|
			next unless item["action"] == "create"
			next unless id.split("/")[0] == type_name
			values << item["record"]
		end
		values.sort! { |a, b| a["_id"] <=> b["_id"] }

		return values
	end

	def who id

		# empty id means empty response
		return nil unless id

		# get locks and stuff
		locks = locks_man.load

		# see who is editing
		locks["changes"].each do |role, change|
			return role if change["items"][id]
		end

		# noone
		return nil
	end

	def commit my_role, force = false

		locks = locks_man.load
		my_change = locks_man.my_change locks, my_role, false

		raise "Invalid state (no change)" unless my_change
		raise "Invalid state #{my_change["state"]}" if ! force && ! [ "done" ].include?(my_change["state"])
		raise "Invalid state #{my_change["state"]}" if force && ! [ "done", "stage" ].include?(my_change["state"])

		my_change["items"].each do |key, item|

			id = "current/#{item["record"]["_id"]}"

			case item["action"]

				when "create"

					item["record"]["_id"] =~ /^([^\/]+)\//
					type = $1

					row = {
						"_id" => id,
						"transaction" => "current",
						"type" => type,
						"source" => "data",
						"value" => item["record"]
					}

					db.create row

				when "update"

					item["record"]["_id"] =~ /^([^\/]+)\//
					type = $1

					row = {
						"_id" => id,
						"_rev" => item["record"]["_rev"],
						"transaction" => "current",
						"type" => type,
						"source" => "data",
						"value" => item["record"]
					}

					db.update row

				when "delete"

					db.delete id, item["record"]["_rev"]

				else

					raise "Internal error"

			end
		end

		locks["changes"].delete my_role

		locks_man.save locks
	end

	def deploy my_role, command, profile, mode = :unstaged, mock = false, background = true

		raise "Invalid deploy mode #{mode}" unless [ :unstaged, :staged, :rollback ].include? mode

		# work out command to execute
		args = %W[
			deploy all
			--profile #{profile}
			--role #{my_role}
		]
		args += %W[ --html --verbose ] unless background
		args += %W[ --mock ] if mock
		args += %W[ --staged ] if mode == :staged
		args += %W[ --rollback ] if mode == :rollback
		full_command = "#{command} #{Mandar.shell_quote args}"

		puts "#{full_command} (#{background ? "background" : "foreground"})"

		if background

			# execute in background, return immediately
			system "#{full_command} >/dev/null 2>/dev/null &"
			return { }

		else

			# execute in foreground, capture output
			lines = []
			IO.popen "#{full_command} 2>&1", "r" do |f|
				while line = f.gets
					lines << line.chomp
				end
			end

			# return
			return {
				output: lines,
				status: $?.exitstatus
			}
		end
	end

	def cancel my_role

		locks = locks_man.load
		my_change = locks_man.my_change locks, my_role, false

		if ! my_change || my_change["state"] != "stage"
			raise "Invalid state"
		end

		locks["changes"].delete my_role

		locks_man.save locks
	end

end
