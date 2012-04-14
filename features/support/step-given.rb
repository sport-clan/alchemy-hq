Given /^an xquery script:$/ do |xquery_text|
	@xquery_text = xquery_text
end

Given /^an xquery module named "([^"]*)":$/ do |module_name, module_text|

	request = {
		"name" => "set library module",
		"arguments" => {
			"module name" => module_name,
			"module text" => module_text,
		}
	}

	reply = zmq_perform request

	case reply["name"]

		when "ok"

			# do nothing

		else

			raise "Error"

	end
end

Given /^an input document:$/ do |input_text|
	@input_text = input_text
end
