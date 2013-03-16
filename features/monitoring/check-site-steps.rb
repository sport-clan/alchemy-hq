require "cucumber/rspec/doubles"

require "hq/systools/monitoring/check-site-script"

Before do

	@check_site_servers = []
	@time = Time.now

	Time.stub(:now) { @time }

	@script =
		HQ::SysTools::Monitoring::CheckSiteScript.new

	@script.args = [
		"--url", "http://hostname/path"
	]

	@script.stdout = StringIO.new
	@script.stderr = StringIO.new

end

Given /^a (warning|critical) time of (\d+) seconds?$/ do
	|type, time_str|
	@script.args += [ "--#{type}", time_str ]
end

Given /^(?:that one|another) server responds in (\d+) seconds?$/ do
	|time_str|
	@check_site_servers << {
		address: "ip-address-#{@check_site_servers.size}",
		response_code: "200",
		response_time: time_str.to_i,
	}
end

When /^check\-site is run$/ do

	Resolv.stub(:getaddresses).and_return(
		@check_site_servers.map {
			|server| server[:address]
		}
	)

	Net::HTTP.any_instance.stub(:start)

	Net::HTTP.any_instance.stub(:request) do
		server = @check_site_servers.shift
		@time += server[:response_time]
		resp = double "response"
		resp.stub(:code).and_return(server[:response_code])
		resp
	end

	@script.main

end

Then /^the status should be (\d+)$/ do
	|status_str|
	@script.status.should == status_str.to_i
end

Then /^the message should be "(.*?)"$/ do |message|
	@script.stdout.string.strip.should == message
end
