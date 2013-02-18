class Mandar::Console::LocksManager

	attr_accessor :db

	def load

		begin

			# load existing row
			return db.get "mandar-locks"

		rescue HQ::CouchDB::CouchNotFoundException

			# create new row
			locks = {
				"_id" => "mandar-locks",
				"next-seq" => 1,
				"deploy" => nil,
				"changes" => {},
			}
			db.create locks
			return db.get "mandar-locks"

		end
	end

	def save locks

		# update database
		ret = db.update locks

		# and update rev
		locks["_rev"] = ret["rev"]
	end

	def my_change locks, my_role, create

		# find existing change
		return locks["changes"][my_role] if locks["changes"][my_role]

		return nil unless create

		# create new change
		my_change = {
			"seq" => locks["next-seq"],
			"role" => my_role,
			"timestamp" => Time.now.to_i,
			"items" => {},
			"state" => "stage",
		}
		locks["changes"][my_role] = my_change
		locks["next-seq"] += 1

		return my_change
	end

=begin
function locks_change_in_progress () {

	// get locks
	$locks = locks_load ();

	// find change with state other than stage
	foreach ($locks->changes as $role => $change) {
		if ($change->state == "stage") continue;
		return $change;
	}

	// none found, return null
	return null;
}
=end

end
