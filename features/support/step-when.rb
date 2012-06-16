Before do
	@input_text = "<xml/>"
	@exceptin = nil
end

When /^I compile the query$/ do
	begin
		@result_text = xquery_session.compile_xquery @xquery_text
		@exception = nil
	rescue => exception
		@exception = exception
		@result_text = nil
	end
end

When /^I run the query$/ do
	begin
		@result_text = xquery_session.run_xquery @input_text
		@exception = nil
	rescue => exception
		@exception = exception
		@result_text = nil
	end
end

When /^I compile the query:$/ do |xquery_text|
	step "an xquery script:", xquery_text
	step "I compile the query"
end

When /^I run the query against:$/ do |input_text|
	step "an input document:", input_text
	step "I run the query"
end

After do
	if @exception
		raise @exception
	end
end