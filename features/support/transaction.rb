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
