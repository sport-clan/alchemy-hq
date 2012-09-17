module Mandar::Console::Forms

	MAX_DEPTH = 16
	COL_STEP = 32

	def make_submit name, label
		return {
			_type: :submit,
			_name: name,
			_label: label,
		}
	end

	def make_hidden name, value, depth = 0
		return {
			_type: :hidden,
			_name: name,
			_value: value,
			_depth: depth,
		}
	end

	def make_bigtext_field name, label, value = "", depth = 0, readonly = false
		return {
			_type: :bigtext_field,
			_name: name,
			_label: label,
			_value: value,
			_depth: depth,
			_readonly: readonly,
		}
	end

	def make_boolean_field name, label, value = false, depth = 0, readonly = false
		return {
			_type: :boolean_field,
			_name: name,
			_label: label,
			_value: value ? true : false,
			_depth: depth,
			_readonly: readonly,
		}
	end

	def render_type_submit content

		render_check content, {
			name: { type: :string, required: true },
			label: { type: :string, required: true },
			depth: { type: :string, required: false },
		}

		attrs = {}
		attrs[:type] = :submit
		attrs[:name] = content[:_name]
		attrs[:value] = content[:_label]

		element_whole :input, attrs
	end

	def make_text_field name, label, value = "", depth = 0, readonly = false
		return {
			_type: :text_field,
			_name: name,
			_label: label,
			_value: value,
			_depth: depth,
			_readonly: readonly,
		}
	end

	def make_generic_field label, depth, content
		content ||= {}
		return {
			_type: :generic_field,
			_label: label,
			_depth: depth,
		}.merge content
	end

	def render_type_generic_field content

		render_check content, {
			label: { type: :string, required: true },
			depth: { type: :integer, required: true },
		}

		element_open :tr, { class: "field field-#{content[:_depth]}" }

		element_open :td, { class: "field-label", colspan: content[:_depth] + 1 }
		element_whole :label, {}, content[:_label]
		element_close :td

		element_open :td, { class: "field-value", colspan: MAX_DEPTH - content[:_depth] + 1 }
		render_children content
		element_close :td

		element_close :tr
	end

	def render_type_bigtext_field content

		render_check content, {
			name: { type: :string, required: true },
			label: { type: :string, required: true },
			value: { type: :string, required: false },
			depth: { type: :integer, required: true },
			readonly: { type: :boolean, required: false },
		}

		element_open :tr, { class: "field field-#{content[:_depth]}" }

		element_open :td, { class: "field-label", colspan: content[:_depth] + 1 }
		element_whole :label, {}, content[:_label]
		element_close :td

		attrs = {}
		attrs[:name] = content[:_name]
		attrs[:rows] = [ [ 2, (content[:_value] || "").count("\n") + 1 ].max, 30 ].min
		attrs[:cols] = 60
		attrs[:disabled] = "" if content[:_readonly]

		element_open :td, { class: "field-value", colspan: MAX_DEPTH - content[:_depth] + 1 }
		element_open :div, { class: "input-hack" }
		element_whole :textarea, attrs, content[:_value] || ""
		element_close :div
		element_close :td

		element_close :tr
	end

	def render_type_boolean_field content

		render_check content, {
			name: { type: :string, required: true },
			label: { type: :string, required: true },
			value: { type: :boolean, required: false },
			depth: { type: :string, required: true },
			readonly: { type: :boolean, required: false },
		}

		element_open :tr, { class: "field field-#{content[:_depth]}" }

		attrs = {}
		attrs[:type] = "checkbox";
		attrs[:name] = content[:_name]
		attrs[:checked] = "" if content[:_value]
		attrs[:disabled] = "" if content[:_readonly]

		element_open :td, { class: "field-label", colspan: content[:_depth] + 1 }
		element_whole :label, {}, content[:_label]
		element_close :td

		element_open :td, { class: "field-value", colspan: MAX_DEPTH - content[:_depth] + 1 }
		element_open :div, { class: "input-hack" }
		element_whole :input, attrs
		element_close :div
		element_close :td

		element_close :tr
	end

	def render_type_fields content

		render_check content, {}

		element_open :table, { class: "fields" }

		element_open :tr, { class: "spacer-row" }
		(0...(MAX_DEPTH + 2)).each do |i|

			element_open :td, { class: "spacer-col spacer-col-#{i}" }
			element_whole :img, { src: path("/empty.png"), width: COL_STEP, height: 1 }
			element_close :td
		end
		element_close :tr

		render_children content

		element_close :table
	end

	def render_type_email_field content

		render_check content, {
			name: { type: :string, required: true },
			label: { type: :string, required: true },
			value: { type: :string, required: false },
			depth: { type: :string, required: true },
			readonly: { type: :boolean, required: false },
		}

		element_open :tr, { class: "field field-#{content[:_depth]}" }

		element_open :td, { class: "field-label", colspan: content[:_depth] + 1 }
		element_whole :label, {}, content[:_label]
		element_close :td

		attrs = {}
		attrs[:type] = "email";
		attrs[:name] = content[:_name]
		attrs[:value] = content[:_value]
		attrs[:disabled] = "" if content[:_readonly]

		element_open :td, { class: "field-value", colspan: MAX_DEPTH - content[:_depth] + 1 }
		element_open :div, { class: "input-hack" }
		element_whole :input, attrs
		element_close :div
		element_close :td

		element_close :tr
	end

	def render_type_hidden content

		render_check content, {
			name: { type: :string, required: true },
			value: { type: :string, required: true },
			depth: { type: :string, required: false },
		}

		attrs = {}
		attrs[:type] = "hidden"
		attrs[:name] = content[:_name]
		attrs[:value] = content[:_value]

		element_whole "input", attrs
	end

	def render_type_text_field content

		render_check content, {
			name: { type: :string, required: true },
			label: { type: :string, required: true },
			value: { type: :string, required: false },
			depth: { type: :integer, required: true },
			readonly: { type: :boolean, required: false },
		}

		element_open :tr, { class: "field field-#{content[:_depth]}" }

		element_open :td, { class: "field-label", colspan: content[:_depth] + 1 }
		element_whole :label, {}, content[:_label]
		element_close :td

		attrs = {}
		attrs[:type] = "text"
		attrs[:name] = content[:_name]
		attrs[:value] = content[:_value]
		attrs[:disabled] = "" if content[:_readonly]

		element_open :td, { class: "field-value", colspan: MAX_DEPTH - content[:_depth] + 1 }
		element_open :div, { class: "input-hack" }
		element_whole :input, attrs
		element_close :div
		element_close :td

		element_close :tr
	end

end
