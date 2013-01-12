Given /^that I have begun a transaction$/ do

	@transaction_id =
		public_api.transaction_begin

end

When /^I call transaction_begin$/ do

	@transaction_id =
		public_api.transaction_begin

end

When /^I call transaction_commit$/ do

	public_api.transaction_commit \
		@transaction_id

end

When /^I call transaction_rollback$/ do

	public_api.transaction_rollback \
		@transaction_id

end

When /^I call data_store$/ do

	@record_id =
		"record id"

	@record_value = {
		some_key: "some value",
		another_key: "another value",
	}

	public_api.data_store \
		@transaction_id,
		@record_id,
		@record_value

end

Then /^the record is stored in the transaction$/ do

	record_value =
		public_api.data_retrieve \
			@transaction_id,
			@record_id

	record_value
		.should == @record_value

end


Then /^a transaction id is returned$/ do

	@transaction_id.should \
		match /^[a-z]{20}$/

end

Then /^a transaction is begun$/ do

	transaction_info =
		mvcc.get_transaction_info @transaction_id

	transaction_info[:state].should \
		equal :begun

end

Then /^the transaction is committed$/ do

	transaction_info =
		mvcc.get_transaction_info @transaction_id

	transaction_info[:state].should \
		equal :committed

end

Then /^the transaction is rolled back$/ do

	transaction_info =
		mvcc.get_transaction_info @transaction_id

	transaction_info[:state].should \
		equal :rolled_back

end
