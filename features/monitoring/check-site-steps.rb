require "cucumber/rspec/doubles"
require "webrick"
require "xml"

require "hq/systools/monitoring/check-site-script"

$web_config = {
	:Port => 10000 + rand(55535),
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

$web_server.mount_proc "/login" do
	|request, response|

	server_address = request.addr[3]
	server = $servers[server_address]

	raise "auth method" unless server[:auth_method] == :form
	raise "request method" unless request.request_method == "POST"
	raise "username" unless request.query["username"] == server[:auth_username]
	raise "password" unless request.query["password"] == server[:auth_password]

	# set session id

	server[:session_id] = (?a..?z).to_a.sample(10).join

	# add session cookie and more to make it harder

	misc_cookie_0 = WEBrick::Cookie.new "foo", "bar"
	misc_cookie_0.path = "/"
	response.cookies << misc_cookie_0

	session_cookie = WEBrick::Cookie.new "session", server[:session_id]
	session_cookie.expires = Time.now + 60
	response.cookies << session_cookie

	misc_cookie_1 = WEBrick::Cookie.new "blah", "meh"
	misc_cookie_0.path = "/"
	response.cookies << misc_cookie_1

end

$web_server.mount_proc "/page" do
	|request, response|

	server_address = request.addr[3]
	server = $servers[server_address]

	server[:request_count] += 1

	if server[:auth_method] == :http
		WEBrick::HTTPAuth.basic_auth request, response, "Realm" do
			|user, pass|
			user == server[:auth_username] &&
			pass == server[:auth_password]
		end
	end

	if server[:auth_method] == :form

		session_cookie =
			request.cookies.find {
				|cookie|
				cookie.name == "session"
			}

		session_id =
			session_cookie.value

		raise "not logged in" \
			unless session_id = server[:session_id]

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
		request_count: 0,
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
		request_count: 0,
		response_code: "200",
		response_time: 0,
		response_body: response_str,
	}

	$servers[server[:address]] = server

end

Given /^(?:one|another) server which requires username "([^"]*)" and password "([^"]+)"$/ do
	|username, password|

	server = {
		address: "127.0.1.#{$servers.size}",
		request_count: 0,
		response_code: "200",
		response_time: 0,
		response_body: "",
		auth_method: :http,
		auth_username: username,
		auth_password: password,
	}

	$servers[server[:address]] = server

end

Given /^one server which requires form based login with "([^"]*)" and "([^"]*)"$/ do
	|username, password|

	server = {
		address: "127.0.1.#{$servers.size}",
		request_count: 0,
		response_code: "200",
		response_time: 0,
		response_body: "",
		auth_method: :form,
		auth_username: username,
		auth_password: password,
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
		config_str.gsub! "${port}", $web_config[:Port].to_s
		config_doc = XML::Document.string config_str
		temp.write config_doc
		temp.flush

		@script.args = [
			"--config", temp.path,
		]

		@script.main

	end

end

Then /^all servers should receive page requests$/ do
	$servers.each do
		|server_address, server|
		server[:request_count].should >= 1
	end
end

Then /^the status should be (\d+)$/ do
	|status_str|
	@script.status.should == status_str.to_i
end

Then /^the message should be "(.*?)"$/ do |message|
	@script.stdout.string.strip.should == message
end
