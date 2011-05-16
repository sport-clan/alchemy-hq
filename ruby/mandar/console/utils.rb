module Mandar::Console::Utils

	def request_method
		return req.meta_vars["REQUEST_METHOD"].downcase.to_sym
	end

	def set_content_type content_type
		resp.content_type = content_type
	end

	def is_admin
		admin_group = config.attributes["admin-group"]
		return in_group admin_group
	end

	def in_group group, user = console_user
		return config.find "boolean (role-member [@role = #{xp group} and @member = #{xp user}])"
	end

	def console_user
		return req.attributes[:user]
	end

	def url path
		ret = "#{config.attributes["url-prefix"]}#{path}"
		return ret.empty? ? "/" : ret
	end

	def path path
		ret = "#{config.attributes["path-prefix"]}#{path}"
		return ret.empty? ? "/" : ret
	end

	def h str
		return CGI.escapeHTML str.to_s
	end

	def u str
		return CGI.escape str.to_s
	end

	def xp str
		return "'" + str.gsub("'", "''") + "'"
	end

	def console_print str
		resp.body += str
	end

	def reindent string, new_indent = ""

		# remove blank lines at start/end
		string.gsub! /^\s*\n|\n\s*$/, ""

		# replace existing indentation with required, based on first line
		string =~ /^(\s*)/
		string.gsub! /^#{$1}/, new_indent

		return string
	end

	def get_vars
		return req_ctx[:get_vars] ||= Hash[
			*req_ctx[:req].meta_vars["QUERY_STRING"].split("&").map { |pair|
				key, val = pair.split("=").map { |one| CGI::unescape one }
				[ key, val ]
			}.flatten
		]
	end

	def get_var name
		return get_vars[name]
	end

	def post_vars
		return req_ctx[:post_vars] ||= Hash[
			*req.body.to_s.split("&").map { |pair|
				key, val = pair.split("=").map { |one| CGI::unescape one }
				[ key, val ]
			}.flatten
		]
	end

	def post_var name
		return post_vars[name]
	end

	def config
		return app_ctx[:config]
	end

	def db
		return app_ctx[:db]
	end

	def locks_man
		return app_ctx[:locks_man]
	end

	def stager
		return app_ctx[:stager]
	end

	def req
		return req_ctx[:req]
	end

	def resp
		return req_ctx[:resp]
	end

	def forbidden
		resp.status = 403
		throw :mandar_abort_request
	end

	def req_ctx
		return Thread.current[:req_ctx]
	end

	def app_ctx
		return Thread.current[:app_ctx]
	end

	def not_found
		resp["Content-Type"] ||= "text/html"
		resp.body = "404 Not found\n" if resp.body.empty?
		resp.status = 404
		throw :mandar_abort_request
	end

	def redirect_moved dest
		resp["Location"] = url dest
		resp.status = 301
		throw :mandar_abort_request
	end

	def redirect_found dest
		resp["Location"] = url dest
		resp.status = 302
		throw :mandar_abort_request
	end

	def redirect_see_other dest
		resp["Location"] = url dest
		resp.status = 303
		throw :mandar_abort_request
	end

	def bad_request
		resp["Content-Type"] ||= "text/html"
		resp.body = "400 Bad request\n" if resp.body.empty?
		resp.status = 400
		throw :mandar_abort_request
	end

	def method_not_allowed
		resp["Content-Type"] ||= "text/html"
		resp.body = "405 Method not allowed\n" if resp.body.empty?
		resp.status = 405
		throw :mandar_abort_request
	end

	def conflict
		resp["Content-Type"] ||= "text/html"
		resp.body = "409 Conflict\n" if resp.body.empty?
		resp.status = 409
		throw :mandar_abort_request
	end

	def internal_error
		resp["Content-Type"] ||= "text/html"
		resp.body = "500 Internal error\n" if resp.body.empty?
		resp.status = 500
		throw :mandar_abort_request
	end

	def to_ymd_hms time, sep = " "
		time = Time.at(time) if time.is_a? Integer
		return case time
			when Time then time.strftime("%Y-%m-%d %H:%M:%S")
			when nil then ""
			else raise "Invalid time type #{time.class}"
		end
	end

	def render_type_console_page content

		set_content_type "text/html"

		render_check content, {
			title: { type: :string, required: true },
			links: { type: :array, required: false },
			notices: { type: :array, required: false },
		}

		console_print "<!DOCTYPE html>\n"

		element_open :html
		element_open :head

		element_whole :title, {}, "#{content[:_title]} - Admin console"
		element_whole :link, { rel: "stylesheet", href: path("/console.css") }
		element_whole :link, { rel: "stylesheet", href: path("/forms.css") }

		element_close :head
		element_open :body

		element_open :header
		element_whole :h1, {}, "#{content[:_title]}"
		element_open :nav
		render make_link "", "Home"
		render make_link "/deploy", "Deploy" if is_admin
		render make_link "/status", "Status" if is_admin
		render make_link "/grapher", "Grapher" if is_admin
		render make_link "/password", "Password"
		element_close :nav
		element_close :header

		element_open :div, { :class => "main" }

		element_open :div, { :class => "content" }
		if content[:_links]
			element_open :nav
			content[:_links].each do |name, link|
				next unless link
				render link
			end
			element_close :nav
		end
		if content[:_notices]
			content[:_notices].each do |notice_name, notice|
				render notice
			end
		end
		render_children content
		element_close :div

		element_open :div, { :class => "sidebar" }
		element_close :div

		element_close :div

		element_close :body
		element_close :html
	end

	def can *perms
		perms << [ "super", "super" ]
		return perms.find do |type, subject|
			perms_xpath = "permission [@type = #{xp type} and @subject = #{xp subject} and @allow = 'yes']"
			role_members_xpath = "role-member [@member = #{xp console_user}]"
			config.find("#{perms_xpath}/@role = #{role_members_xpath}/@role")
		end
	end

	def must *perms
		forbidden unless can *perms
	end

end
