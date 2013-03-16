require "cucumber/rspec/doubles"
require "webrick"

require "hq/systools/monitoring/check-site-script"

$web_config = {
	Port: 10000 + rand(55536),
	AccessLog: [],
	Logger: WEBrick::Log::new("/dev/null", 7),
}

$web_server =
	WEBrick::HTTPServer.new \
		$web_config

Thread.new do
	$web_server.start
end

at_exit do
	$web_server.shutdown
end

$servers = {}

$web_server.mount_proc "/path" do
	|request, response|

	server_address = request.addr[3]
	server = $servers[server_address]

	response.status = server[:response_code]
	response.body = server[:response_body]

	$time += server[:response_time]

end

Before do

	$servers = {}
	$time = Time.now

	Time.stub(:now) { $time }

	@script =
		HQ::SysTools::Monitoring::CheckSiteScript.new

	@script.args = [
		"--url", "http://hostname:#{$web_config[:Port]}/path"
	]

	@script.stdout = StringIO.new
	@script.stderr = StringIO.new

end

Given /^a (warning|critical|timeout) (?:time )?of (\d+) seconds?$/ do
	|type, time_str|
	@script.args += [ "--#{type}", time_str ]
end

Given /^a regex of "([^"]*)"$/ do
	|regex_str|
	@script.args += [ "--regex", regex_str ]
end

Given /^(?:that one|another) server responds in (\d+) seconds?$/ do
	|time_str|

	server = {
		address: "127.0.1.#{$servers.size}",
		response_code: "200",
		response_time: time_str.to_i,
		response_body: "",
	}

	$servers[server[:address]] = server

end

Given /^(?:that one|another) server responds with "(.*?)"$/ do
	|response_str|

	server = {
		address: "127.0.1.#{$servers.size}",
		response_code: "200",
		response_time: 0,
		response_body: response_str,
	}

	$servers[server[:address]] = server

end

When /^check\-site is run$/ do

	Resolv.stub(:getaddresses).and_return(
		$servers.values.map {
			|server| server[:address]
		}
	)

	@script.main

end

Then /^the status should be (\d+)$/ do
	|status_str|
	@script.status.should == status_str.to_i
end

Then /^the message should be "(.*?)"$/ do |message|
	@script.stdout.string.strip.should == message
end
