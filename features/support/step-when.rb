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

	require "xml"

	begin

		@result_text =
			xquery_session.run_xquery @input_text \
		do
			|name, args|

			case name

			when "get record by id"
				record = XML::Node.new "get-record-by-id"
				args.each do
					|name, value|
					record[name] = value
				end
				[ record.to_s ]

			when "get record by id parts"
				record = XML::Node.new "get-record-by-id-parts"
				record["type"] = args["type"]
				args["id parts"].each do
					|arg_part|
					part = XML::Node.new "part"
					part["value"] = arg_part
					record << part
				end
				[ record.to_s ]

			when "search records"
				record = XML::Node.new "search-records"
				record["type"] = args["type"]
				[ record.to_s ]

			else
				puts "ERROR #{name}"
				[]

			end

		end

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
