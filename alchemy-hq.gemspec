#!/usr/bin/env ruby

HQ_DIR = File.expand_path "..", __FILE__ \
	unless defined? HQ_DIR

$LOAD_PATH.unshift "#{HQ_DIR}/ruby" \
	unless $LOAD_PATH.include? "#{HQ_DIR}/ruby"

Gem::Specification.new do
	|spec|

	spec.name = "alchemy-hq"
	spec.version = "0.0.0"
	spec.platform = Gem::Platform::RUBY
	spec.authors = [ "James Pharaoh" ]
	spec.email = [ "james@phsys.co.uk" ]
	spec.homepage = "https://github.com/jamespharaoh/alchemy-hq"
	spec.summary = "Alchemy HQ"
	spec.description = "Configuration management framework"
	spec.required_rubygems_version = ">= 1.3.6"

	spec.rubyforge_project = "alchemy-hq"

	spec.add_dependency "amqp", ">= 0.9.8"
	spec.add_dependency "json_pure", ">= 1.7.7"
	spec.add_dependency "libxml-ruby"
	spec.add_dependency "multi_json"
	spec.add_dependency "net-dns", ">= 0.7.1"
	spec.add_dependency "rake", ">= 10.0.3"
	spec.add_dependency "sys-filesystem" # TODO remove this

	spec.add_development_dependency "cucumber", ">= 1.2.1"
	spec.add_development_dependency "rspec", ">= 2.12.0"
	spec.add_development_dependency "rspec_junit_formatter"
	spec.add_development_dependency "simplecov"

	spec.files = Dir[

		"c++/Makefile",
		"c++/Rakefile",
		"c++/xquery-server.cc",

		"features/**/*.feature",
		"features/**/*.rb",

		"ruby/**/*.rb",

	]

	spec.test_files = []

	spec.executables = Dir.new("bin").entries - [ ".", ".." ]

	spec.require_paths = [ "ruby" ]

end
