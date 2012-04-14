Before do
	@input_text = "<xml/>"
end

When /^I perform the transform$/ do

	request = {
		"name" => "run xquery",
		"arguments" => {
			"xquery text" => @xquery_text,
			"input text" => @input_text,
		}
	}

	reply = xquery_client.perform request

	case reply["name"]

		when "ok"

			@result_text = reply["arguments"]["result text"]

		else

			raise "Error"

	end

end
