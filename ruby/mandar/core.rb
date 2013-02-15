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
require "webrick"

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
		i = 0
		map { |item| yield item, (i += 1) - 1 }
	end
end

require "mandar/mandar"

module Mandar::Core
end

require "mandar/core/config"
require "mandar/core/script"
