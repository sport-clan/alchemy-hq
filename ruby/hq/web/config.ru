#!/usr/bin/env ruby

require "./settings"

require "pp"
require "xml"

$LOAD_PATH << "hq/ruby"

require "hq/web"

def main

	$log = File.open "tmp/log", "a"
	$log.sync = true
	$stdout.reopen "tmp/log", "a"
	$stderr.reopen "tmp/log", "a"

	container = HQ::Web::Container.new
	container.init "hq-web.xml"
	run proc { |env| container.handle env }
end

main
