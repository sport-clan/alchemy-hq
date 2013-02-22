# core deps
require "cgi"
require "find"
require "fileutils" if RUBY_VERSION =~ /^1\.9\./
require "ftools" if RUBY_VERSION =~ /^1\.8\./
require "net/http"
require "pp"
require "set"
require "socket"
require "tempfile"
require "thread"
require "uri"
#require "webrick"

%W[
	rubygems
	AWS
	json
	xml
	zorba_api
].each do |mod|
	begin
		require mod
	rescue LoadError => e
	end
end

# set MANDAR constant

unless defined? MANDAR

	MANDAR =
		File.expand_path "../../..", __FILE__

end

# small additions to standard library
class Array
	def map_with_index
		map { |item| yield item, (i += 1) - 1 }
	end
end

require "mandar/mandar"
require "mandar/aws"
require "mandar/deploy"
require "mandar/ec2"
require "mandar/grapher"
require "mandar/support"
require "mandar/tools"
