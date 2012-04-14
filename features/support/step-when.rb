Before do
	@input_text = "<xml/>"
end

When /^I perform the transform$/ do
	begin
		@result_text = xquery_client.run_xquery @xquery_text, @input_text
		@exception = nil
	rescue => exception
		@exception = exception
		@result_text = nil
	end
end
