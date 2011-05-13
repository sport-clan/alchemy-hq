
require "pp"

require "rubygems"

gem "test-unit"
require "test/unit"

require "flexmock/test_unit"

module Mandar end

module Mandar::Console end

require "mandar/console/data.rb"
require "mandar/console/stager.rb"

class StagerTest < Test::Unit::TestCase

	def gen_record age, rev = nil
		record = {}
		record["_id"] = "some-type/some-id"
		record["_rev"] = rev if rev
		record["field-one"] = "#{age}-value-one"
		record["field-two"] = "#{age}-value-two"
		record["mandar_type"] = "some-type"
		return record
	end

	def gen_locks *changes
		locks = {}
		locks["_id"] = "mandar-locks"
		locks["_rev"] = "locks-revision"
		locks["changes"] = Hash[*changes.map { |change| [ change["role"], change ] }.flatten(1)]
		return locks
	end

	def gen_change state, *items
		change = {}
		change["role"] = @user
		change["timestamp"] = @now.to_i
		change["items"] = Hash[*items.map { |item| [ item["record"]["_id"], item ] }.flatten(1)]
		change["state"] = state
		return change
	end

	def gen_item action, record, rev
		item = {}
		item["action"] = action
		item["record"] = record
		item["rev"] = rev
		return item
	end

	def setup
		@now = Time.now
		@user = "user-#{rand(899) + 100}"

		@entropy = flexmock "entropy"
		@db = flexmock "db"
		@locks_man = flexmock "locks_man"

		@stager = Mandar::Console::Stager.new
		@stager.entropy = @entropy
		@stager.db = @db
		@stager.locks_man = @locks_man
	end

	def expect
		@entropy.should_expect do |entropy|
			entropy.should_be_strict
			@db.should_expect do |db|
				db.should_be_strict
				@locks_man.should_expect do |locks_man|
					locks_man.should_be_strict
					yield entropy, db, locks_man
				end
			end
		end
	end

	def test_commit_create

		record = gen_record "new", "db-revision"
		locks = gen_locks gen_change("done", gen_item("create", gen_record("new", "db-revision"), "rand-0"))
		locks_after = gen_locks

		expect do |entropy, db, locks_man|
			locks_man.load { locks }
			locks_man.my_change(locks, @user, false) { locks["changes"][@user] }
			db.create(record)
			locks_man.save(locks)
		end

		@stager.commit @user

		assert_equal locks_after, locks

	end

	def test_commit_update

		record = gen_record "new", "db-revision"
		locks = gen_locks(gen_change("done", gen_item("update", gen_record("new", "db-revision"), "rand-0")))
		locks_after = gen_locks

		expect do |entropy, db, locks_man|
			locks_man.load { locks }
			locks_man.my_change(locks, @user, false) { locks["changes"][@user] }
			db.update(record)
			locks_man.save(locks)
		end

		@stager.commit @user

		assert_equal locks_after, locks

	end

	def test_commit_delete

		locks = gen_locks(gen_change("done", gen_item("delete", gen_record("new", "db-revision"), "rand-0")))
		locks_after = gen_locks

		expect do |entropy, db, locks_man|
			locks_man.load { locks }
			locks_man.my_change(locks, @user, false) { locks["changes"][@user] }
			db.delete("some-type/some-id", "db-revision")
			locks_man.save(locks)
		end

		@stager.commit @user

		assert_equal locks_after, locks
	end

	def test_stager_put_create

		record = gen_record("new")
		locks = gen_locks(gen_change("stage"))
		locks_after = gen_locks(gen_change("stage", gen_item("create", gen_record("new"), "rand-0")))

		expect do |entropy, db, locks_man|
			locks_man.load() { locks }
			locks_man.my_change(locks, @user, true) { locks["changes"][@user] }
			entropy.rand_token() { "rand-0" }
			locks_man.save(locks)
		end

		@stager.put record, :create, @user

		assert_equal locks_after, locks
	end

	def test_stager_put_update

		record = gen_record("new", "db-revision")
		locks = gen_locks(gen_change("stage"))
		locks_after = gen_locks(gen_change("stage", gen_item("update", gen_record("new", "db-revision"), "rand-1")))

		expect do |entropy, db, locks_man|
			locks_man.load() { locks }
			locks_man.my_change(locks, @user, true) { locks["changes"][@user] }
			entropy.rand_token() { "rand-1" }
			locks_man.save(locks)
		end

		@stager.put record, :update, @user

		assert_equal locks_after, locks
	end

	def test_stager_put_delete

		record = gen_record("new", "db-revision")
		locks = gen_locks(gen_change("stage"))
		locks_after = gen_locks(gen_change("stage", gen_item("delete", gen_record("new", "db-revision"), "rand-1")))

		expect do |entropy, db, locks_man|
			locks_man.load() { locks }
			locks_man.my_change(locks, @user, true) { locks["changes"][@user] }
			entropy.rand_token() { "rand-1" }
			locks_man.save(locks)
		end

		@stager.put record, :delete, @user

		assert_equal locks_after, locks
	end


	def test_stager_put_update_after_create

		record = gen_record("new", "rand-0")
		locks = gen_locks(gen_change("stage", gen_item("create", gen_record("old"), "rand-0")))
		locks_after = gen_locks(gen_change("stage", gen_item("create", gen_record("new"), "rand-1")))

		expect do |entropy, db, locks_man|
			locks_man.load() { locks }
			locks_man.my_change(locks, @user, true) { locks["changes"][@user] }
			entropy.rand_token() { "rand-1" }
			locks_man.save(locks)
		end

		@stager.put record, :update, @user

		assert_equal locks_after, locks
	end

	def test_stager_put_delete_after_create

		record = gen_record("new", "rand-0")
		locks = gen_locks(gen_change("stage", gen_item("create", gen_record("old"), "rand-0")))
		locks_after = gen_locks(gen_change("stage"))

		expect do |entropy, db, locks_man|
			locks_man.load() { locks }
			locks_man.my_change(locks, @user, true) { locks["changes"][@user] }
			locks_man.save(locks)
		end

		@stager.put record, :delete, @user

		assert_equal locks_after, locks
	end

	def test_stager_put_update_after_update

		record = gen_record("new", "rand-0")
		locks = gen_locks(gen_change("stage", gen_item("update", gen_record("old", "db-revision"), "rand-0")))
		locks_after = gen_locks(gen_change("stage", gen_item("update", gen_record("new", "db-revision"), "rand-1")))

		expect do |entropy, db, locks_man|
			locks_man.load() { locks }
			locks_man.my_change(locks, @user, true) { locks["changes"][@user] }
			entropy.rand_token() { "rand-1" }
			locks_man.save(locks)
		end

		@stager.put record, :update, @user

		assert_equal locks_after, locks
	end

	def test_stager_put_delete_after_update

		record = gen_record("new", "rand-0")
		locks = gen_locks(gen_change("stage", gen_item("update", gen_record("old", "db-revision"), "rand-0")))
		locks_after = gen_locks(gen_change("stage", gen_item("delete", gen_record("new", "db-revision"), "rand-1")))

		expect do |entropy, db, locks_man|
			locks_man.load() { locks }
			locks_man.my_change(locks, @user, true) { locks["changes"][@user] }
			entropy.rand_token() { "rand-1" }
			locks_man.save(locks)
		end

		@stager.put record, :delete, @user

		assert_equal locks_after, locks
	end

	def test_stager_put_create_after_delete

		record = gen_record("new")
		locks = gen_locks(gen_change("stage", gen_item("delete", gen_record("old", "db-revision"), "rand-0")))
		locks_after = gen_locks(gen_change("stage", gen_item("update", gen_record("new", "db-revision"), "rand-1")))

		expect do |entropy, db, locks_man|
			locks_man.load() { locks }
			locks_man.my_change(locks, @user, true) { locks["changes"][@user] }
			entropy.rand_token() { "rand-1" }
			locks_man.save(locks)
		end

		@stager.put record, :create, @user

		assert_equal locks_after, locks
	end

end
