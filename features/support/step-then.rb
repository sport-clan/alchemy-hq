Then /^the result should be:$/ do |result_text|
	@result_text.should == result_text
end

Then /^I should get an error$/ do
	@exception.should_not be_nil
end
