Before do
	@input_text = "<xml/>"
end

When /^I perform the transform$/ do
	@result_text = xquery_client.run_xquery @xquery_text, @input_text
end
