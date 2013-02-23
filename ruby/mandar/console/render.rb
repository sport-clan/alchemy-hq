module Mandar::Console::Render

	include Mandar::Console::Utils

	def render content
		Thread.current[:render_error_handled] = false

		case content
			when NilClass then return
			when Array then return content.each { |content_item| render content_item }
			when String then content = make_html content
		end

		if content[:_type]
			self.send "render_type_#{content[:_type]}", content
		else
			content.each { |key, sub_content| render sub_content } unless content[:_type]
		end

	rescue
		unless Thread.current[:render_error_handled]
			puts "content which generated error:"
			pp content
			Thread.current[:render_error_handled] = true
		end
		raise

	end

	def render_children parent
		parent.each do |key, child|
			next if key =~ /^_/
			render child
		end
	end

	def render_check content, specs

		content = content.clone
		errors = []

		specs.each do |name, spec|

			exists = content.include? "_#{name}".to_sym
			value = content ["_#{name}".to_sym]

			# check for missing required fields
			if spec[:required] && ! exists
				errors << "Content of type #{content[:_type]} missing required property :_#{name}<br>\n"
				next
			end

			# skip missing optional fields
			next unless exists

			# TODO check something here

			# remove field
			content.delete "_#{name}".to_sym
		end

		content.each do |name, child|

			next if name == :_type
			next unless name.to_s =~ /^\_/

			errors << "Content of type #{content[:_type]} has extra property #{name}<br>\n"
		end

		errors.each { |error| puts error }
		raise errors[0] unless errors.empty?
	end

# ======================================== make functions

	def make_para *content_array
		ret = {
			_type: :paragraph,
		}
		content_array.each_with_index do |content, i|
			ret[i] = content
		end
		return ret
	end

	def make_para_text text
		return make_para make_text(text)
	end

	def make_html html
		return {
			_type: :html,
			_content: html,
		}
	end

	def make_text text
		return make_html h text
	end

	def make_link href, label
		return {
			_type: :link,
			_label: label,
			_href: href,
		}
	end

	def make_notice mood, content
		content = { content: make_para(content) } if content.is_a? String
		return {
			_type: :notice,
			_mood: mood,
		}.merge content
	end

	def make_info content
		return make_notice :info, content
	end

	def make_warning content
		return make_notice :warning, content
	end

	def make_error content
		return make_notice :error, content
	end

	def make_fatal content
		return make_notice :fatal, content
	end

	def make_div content = {}
		return {
			_type: :div,
		}.merge content
	end

	def make_item content
		return {
			_type: :item,
		}.merge content
	end

# ======================================== tag open/close function

	def element_indent_inc
		req_ctx[:element_indent_current] += app_ctx[:element_indent]
	end

	def element_indent_dec
		new_len = req_ctx[:element_indent_current].length - app_ctx[:element_indent].length
		req_ctx[:element_indent_current] = req_ctx[:element_indent_current][0...new_len]
	end

	def element name, attributes

		console_print "<#{name}"

		attributes.each do |key, value|
			console_print " #{key}=\"#{h value}\""
		end

		console_print ">"
	end

	def element_whole name, attributes = {}, text = false

		console_print req_ctx[:element_indent_current]

		element name, attributes

		if text
			console_print h(text);
			console_print "</#{name}>"
		end

		console_print "\n"
	end

	def element_open name, attributes = {}

		console_print req_ctx[:element_indent_current];
		element name, attributes
		console_print "\n"

		element_indent_inc
	end

	def element_close name

		element_indent_dec

		console_print req_ctx[:element_indent_current]
		console_print "</#{name}>"
		console_print "\n"
	end

# ======================================== render_type functions

	def render_type_buttonset content

		render_check content, {}

		element_open :p, {}
		render_children content
		element_close :p
	end

	def render_type_column content

		render_check content, {
			label: { type: :string, required: true },
			mode: { type: :symbol, required: true },
		}

		element_whole :th, {}, content[:_label]

	end

	def render_type_div content

		render_check content, {
			class: { type: :string, required: false },
		}

		attrs = {}

		if content[:_class]
			attrs[:class] =
				content[:_class].to_s.gsub(?_, ?-)
		end

		if content[:_style]
			attrs[:style] =
				content[:_style].map {
					|key, value|
					"#{key}: #{value}"
				}.join "; "
		end

		element_open :div, attrs
		render_children content
		element_close :div
	end

	def render_type_html content

		render_check content, {
			content: {
				type: :string,
				required: true,
			},
		}

		content = content[:_content]

		content = reindent content, req_ctx[:element_indent_current]

		console_print content
		console_print "\n"
	end

	def render_type_item content

		render_check content, {}

		render_children content
	end

	def render_type_number_field content

		render_check content, {
			name: { type: :string, required: true },
			label: { type: :string, required: true },
			value: { type: :string, required: false },
			depth: { type: :string, required: false },
		}

		element_open :div, { class: "field field-#{content[:_depth]}" }

		element_whole :label, {}, content[:_label]

		attrs = {}
		attrs[:type] = "number";
		attrs[:name] = content[:_name]
		attrs[:value] = content[:_value]

		element_open :div, { class: "field-value" }
		element_open :div, { class: "input-hack" }
		element_whole :input, attrs
		element_close :div
		element_close :div

		element_close :div
	end

	def render_type_form content

		render_check content, {
			method: { type: :string, required: true },
			style: { type: :hash, required: false },
		}

		attrs = {}

		attrs[:method] = content[:_method] if content[:_method]

		if content[:_style]
			attrs[:style] =
				content[:_style].map {
					|key, value|
					"#{key}: #{value}"
				}.join "; "
		end

		element_open :form, attrs
		render_children content
		element_close :form
	end

	def render_type_link content

		render_check content, {
			label: {
				type: :string,
				required: true,
			},
			href: {
				type: :string,
				required: true,
			},
		}

		attrs = {}
		attrs[:href] = path content[:_href]

		element_whole :a, attrs, content[:_label]
	end

	def render_type_notice content

		render_check content, {
			mood: { type: :symbol, required: true },
		}

		element_open :div, { class: "notice" }
		render_children content
		element_close :div
	end

	def render_type_paragraph content

		render_check content, { }

		element_open :p

		render_children content

		element_close :p
	end

	def render_type_section content

		render_check content, {
			heading: { type: :string, required: true },
			class: { type: :string, required: false },
		}

		opts = {}
		opts[:class] = content[:_class].to_s.gsub("_", "-") if content[:_class]
		element_open :section, opts

		element_whole :h1, {}, content[:_heading]

		render_children content

		element_close :section
	end

	def render_type_unordered_list content

		render_check content, {}

		element_open :ul

		render_flatten(content).each do |item|
			element_open :li
			render item
			element_close :li
		end

		element_close :ul
	end

	def render_flatten content, top_level = true
		return case content

			when NilClass
				[]

			when Array
				content.map { |item| render_flatten(item, false) }.flatten 1

			when Hash
				! top_level && content[:_type] ? [ content ] :
					content.map { |key, value| key =~ /^_/ ? [] : render_flatten(value, false) }.flatten(1)

			else [ content ]
		end
	end

	def render_type_table content

		render_check content, {
			columns: { required: true },
			data: { required: true },
		}

		element_open :table
		element_open :thead
		element_open :tr

		content[:_columns].each do |key, column|
			render column
		end

		element_close :tr
		element_close :thead
		element_open :tbody

		content[:_data].each do |row_key, row|
			element_open :tr

			content[:_columns].each do |column_key, column|
				case column[:_mode]

				when :render
					element_open :td
					render row[column_key]
					element_close :td

				when :text
					element_whole :td, {}, row[column_key]

				else
					element_whole :td, {}, "Unknown column mode: #{column[:_mode]}"
				end
			end

			element_close :tr
		end

		element_close :tbody
		element_close :table
	end

end
