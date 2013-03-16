require "cucumber/rspec/doubles"
require "webrick"
require "xml"

require "hq/systools/monitoring/check-site-script"

$web_config = {
	:Port => 10000 + rand(55536),
	:AccessLog => [],
	:Logger => WEBrick::Log::new("/dev/null", 7),
	:DoNotReverseLookup => true,
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

$web_server.mount_proc "/page" do
	|request, response|

	server_address = request.addr[3]
	server = $servers[server_address]

	if server[:require_username]
		WEBrick::HTTPAuth.basic_auth request, response, "Realm" do
			|user, pass|
			user == server[:require_username] &&
			pass == server[:require_password]
		end
	end

	response.status = server[:response_code]
	response.body = server[:response_body]

	$time += server[:response_time]

end

Before do

	$servers = {}
	$time = Time.now

	@configs = {}

	Time.stub(:now) { $time }

end

Given /^a config "(.*?)":$/ do
	|name, content|
	@configs[name] = content
end

Given /^(?:one|another) server which responds in (\d+) seconds?$/ do
	|time_str|

	server = {
		address: "127.0.1.#{$servers.size}",
		response_code: "200",
		response_time: time_str.to_i,
		response_body: "",
	}

	$servers[server[:address]] = server

end

Given /^(?:one|another) server which responds with "(.*?)"$/ do
	|response_str|

	server = {
		address: "127.0.1.#{$servers.size}",
		response_code: "200",
		response_time: 0,
		response_body: response_str,
	}

	$servers[server[:address]] = server

end

Given /^(?:one|another) server which requires username "([^"]+)" and password "([^"]+)"$/ do
	|username, password|

	server = {
		address: "127.0.1.#{$servers.size}",
		response_code: "200",
		response_time: 0,
		response_body: "",
		require_username: username,
		require_password: password,
	}

	$servers[server[:address]] = server

end

When /^check\-site is run with config "([^"]*)"$/ do
	|config_name|

	Resolv.stub(:getaddresses).and_return(
		$servers.values.map {
			|server| server[:address]
		}
	)

	@script =
		HQ::SysTools::Monitoring::CheckSiteScript.new

	@script.stdout = StringIO.new
	@script.stderr = StringIO.new

	Tempfile.open "check-site-script-" do
		|temp|

		config_str = @configs[config_name]
		base_url = "http://hostname:#{$web_config[:Port]}"
		config_str.gsub! "${base-url}", base_url
		config_doc = XML::Document.string config_str
		temp.write config_doc
		temp.flush

		@script.args = [
			"--config", temp.path,
		]

		@script.main

	end

end

Then /^the status should be (\d+)$/ do
	|status_str|
	@script.status.should == status_str.to_i
end

Then /^the message should be "(.*?)"$/ do |message|
	@script.stdout.string.strip.should == message
end
