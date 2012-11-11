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

Then /^a transaction should be begun$/ do
	mvcc.transactions.keys.should include @transaction_id
end

Then /^the transaction should be committed$/ do
	mvcc.transactions.keys.should_not include @transaction_id
end

Then /^the transaction should be rolled back$/ do
	mvcc.transactions.keys.should_not include @transaction_id
end
