Given /^an xquery script:$/ do |xquery_text|
	@xquery_text = xquery_text
end

Given /^an xquery module named "([^"]*)":$/ do |module_name, module_text|
	xquery_client.set_library_module module_name, module_text
end

Given /^an input document:$/ do |input_text|
	@input_text = input_text
end
