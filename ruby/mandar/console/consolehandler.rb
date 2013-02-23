require "hq/dir"

class Mandar::Console::ConsoleHandler

	include Mandar::Console::Utils

	def handle path

		case path

		when /^(|\/)$/
			Mandar::Console::Home.new.handle

		when /^\/api(\/.*)?$/
			app_ctx[:api_handler].handle $1 || ""

		when /^\/console\.css$/
			set_content_type "text/css"
			css = File.read "#{HQ::DIR}/etc/console.css"
			css_new = css.clone
			css.scan /^DEFINE ([a-z][a-z0-9]*(?:-[a-z][a-z0-9]*)*) (.+)$/ do |name, repl|
				css_new.gsub! /\b#{name}\b/, repl
			end
			console_print css_new

		when /^\/forms\.css$/
			set_content_type "text/css"
			console_print ".fields .spacer-col { width: #{Mandar::Console::Forms::COL_STEP}px; }\n"
			console_print ".fields .spacer-col-0 { width: 0; }\n"
			console_print ".fields .spacer-col-#{Mandar::Console::Forms::MAX_DEPTH} { width: 100%; }\n"
			(1..Mandar::Console::Forms::MAX_DEPTH).each do |i|
				console_print ".field-#{i} .field-label { border-left: #{Mandar::Console::Forms::COL_STEP * i}px solid white; }\n"
			end

		when /^\/empty.png$/
			set_content_type "image/png"
			png = File.read "#{HQ::DIR}/etc/empty.png"
			console_print png

		when /^\/grapher$/
			Mandar::Console::GrapherIndex.new.handle

		when /^\/grapher\/graph\/([^\/]+)\/([^\/]+)$/
			get_vars["graph-name"] = $1
			get_vars["scale-name"] = $2
			Mandar::Console::GrapherGraph.new.handle

		when /^\/deploy$/
			Mandar::Console::Deploy.new.handle

		when /^\/password$/
			Mandar::Console::Password.new.handle

		when /^\/status$/
			Mandar::Console::Status.new.handle

		when /^\/type\/list\/([^\/]+)$/
			get_vars["type_name"] = $1
			Mandar::Console::TypeList.new.handle

		when /^\/type\/edit\/(.+)$/
			get_vars["id"] = $1
			Mandar::Console::TypeEdit.new.handle

		when /^\/about$/
			set_content_type "text/plain"
			console_print "LibXML ruby version: #{XML::VERSION}\n"
			console_print "LibXML native version: #{XML::LIBXML_VERSION}\n"

		when /^\/webs$/
			set_content_type "text/html"
			console_print "<!DOCTYPE html>\n"
			console_print "<script src=\"http://code.jquery.com/jquery-1.9.1.js\"></script>\n"
			console_print "<script src=\"/console.js\"></script>\n"

		when /^\/console\.js$/
			set_content_type "text/javascript"
			js = File.read "#{HQ::DIR}/etc/console.js"
			console_print js

		else
			not_found

		end

	end

end
