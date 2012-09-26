require "tempfile"

gem "test-unit"
require "test/unit"

require "hq/tools/getopt"

class GetoptTest < Test::Unit::TestCase

	def setup
	end

	def go expect, args, spec
		ret, remain = HQ::Tools::Getopt.process args, spec
		assert_equal expect, ret
	end

	def go_error args, spec, message
		Tempfile.open "getopt-test" do |tmp|
			$stderr.reopen tmp.path, "w"
			assert_raise HQ::Tools::GetoptError do
				HQ::Tools::Getopt.process args, spec
			end
			$stderr.flush
			assert_equal "#{$0}: #{message}", File.read(tmp.path).chomp
		end
	end

	# ---------------------------------------- required

	def test_required
		args = [ "--arg-0", "arg_0_value" ]
		spec = [ { name: :arg_0, required: true } ]
		expect = { :arg_0 => "arg_0_value" }
		go expect, args, spec
	end

	def test_required_missing
		args = [ ]
		spec = [ { name: :arg_0, required: true } ]
		go_error args, spec, "option '--arg-0' is required"
	end

	def test_required_no_arg
		args = [ "--arg-0" ]
		spec = [ { name: :arg_0, required: true } ]
		go_error args, spec, "option `--arg-0' requires an argument"
	end

	# ---------------------------------------- required with regexp

	def test_required_regexp
		args = [ "--arg-0", "abc" ]
		spec = [ { name: :arg_0, required: true, regex: /[abc]{3}/ } ]
		expect = { :arg_0 => "abc" }
		go expect, args, spec
	end

	def test_required_regexp_missing
		args = [ ]
		spec = [ { name: :arg_0, required: true, regex: /[abc]{3}/ } ]
		go_error args, spec, "option '--arg-0' is required"
	end

	def test_required_regexp_no_arg
		args = [ "--arg-0" ]
		spec = [ { name: :arg_0, required: true, regex: /[abc]{3}/ } ]
		go_error args, spec, "option `--arg-0' requires an argument"
	end

	def test_required_regexp_mismatch
		args = [ "--arg-0", "abcd" ]
		spec = [ { name: :arg_0, required: true, regex: /[abc]{3}/ } ]
		go_error args, spec, "option '--arg-0' is invalid: abcd"
	end

	# ---------------------------------------- conversions

	def test_required_conversion_integer_present
		args = [ "--arg-0", "123" ]
		spec = [ { name: :arg_0, required: true, regex: /[0-9]+/, convert: :to_i } ]
		expect = { :arg_0 => 123 }
		go expect, args, spec
	end

	def test_optional_conversion_no_default_present
		args = [ "--arg-0", "123" ]
		spec = [ { name: :arg_0, regex: /[0-9]+/, convert: :to_i } ]
		expect = { :arg_0 => 123 }
		go expect, args, spec
	end

	def test_optional_conversion_no_default_absent
		args = [ ]
		spec = [ { name: :arg_0, regex: /[0-9]+/, convert: :to_i } ]
		expect = { :arg_0 => nil }
		go expect, args, spec
	end

	def test_optional_conversion_with_default_present
		args = [ "--arg-0", "123" ]
		spec = [ { name: :arg_0, default: 10, regex: /[0-9]+/, convert: :to_i } ]
		expect = { :arg_0 => 123 }
		go expect, args, spec
	end

	def test_optional_conversion_with_default_absent
		args = [ ]
		spec = [ { name: :arg_0, default: 10, regex: /[0-9]+/, convert: :to_i } ]
		expect = { :arg_0 => 10 }
		go expect, args, spec
	end

	# ---------------------------------------- optional

	def test_optional_present
		args = [ "--arg-0", "arg_0_value" ]
		spec = [ { name: :arg_0 } ]
		expect = { :arg_0 => "arg_0_value" }
		go expect, args, spec
	end

	def test_optional_absent
		args = [ ]
		spec = [ { name: :arg_0 } ]
		expect = { :arg_0 => nil }
		go expect, args, spec
	end

	def test_optional_value_present
		args = [ "--arg-0", "value_0" ]
		spec = [ { name: :arg_0, default: "default_0" } ]
		expect = { :arg_0 => "value_0" }
		go expect, args, spec
	end

	def test_optional_value_absent
		args = [ ]
		spec = [ { name: :arg_0, default: "default_0" } ]
		expect = { :arg_0 => "default_0" }
		go expect, args, spec
	end

	# ---------------------------------------- multi

	def test_multi_zero
		args = %W[ ]
		spec = [ { name: :arg0, multi: true } ]
		expect = { :arg0 => [ ] }
		go expect, args, spec
	end

	def test_multi_one
		args = %W[ --arg0 arg0-value0 ]
		spec = [ { name: :arg0, multi: true } ]
		expect = { :arg0 => [ "arg0-value0" ] }
		go expect, args, spec
	end

	def test_multi_two
		args = %W[ --arg0 arg0-value0 --arg0 arg0-value1 ]
		spec = [ { name: :arg0, multi: true } ]
		expect = { :arg0 => [ "arg0-value0", "arg0-value1" ] }
		go expect, args, spec
	end

	def test_multi_required
		args = %W[ --arg0 arg0-value0 --arg0 arg0-value1 ]
		spec = [ { name: :arg0, multi: true, required: true } ]
		expect = { :arg0 => [ "arg0-value0", "arg0-value1" ] }
		go expect, args, spec
	end

	def test_multi_required_missing
		args = %W[ ]
		spec = [ { name: :arg0, multi: true, required: true } ]
		expect = { :arg0 => [ "arg0-value0", "arg0-value1" ] }
		go_error args, spec, "option '--arg0' is required"
	end

	def test_multi_regex
		args = %W[ --arg0 arg0-value0 --arg0 arg0-value1 ]
		spec = [ { name: :arg0, multi: true, regex: /arg0-value[0-9]/ } ]
		expect = { :arg0 => [ "arg0-value0", "arg0-value1" ] }
		go expect, args, spec
	end

	def test_multi_regex_invalid
		args = %W[ --arg0 arg0-value0 --arg0 arg0-value1 ]
		spec = [ { name: :arg0, multi: true, regex: /arg1-value[0-9]/ } ]
		expect = { :arg0 => [ "arg0-value0", "arg0-value1" ] }
		go_error args, spec, "option '--arg0' is invalid: arg0-value0"
	end

	# ---------------------------------------- boolean

	def test_boolean_off
		args = %W[ ]
		spec = [ { name: :arg0, boolean: true } ]
		expect = { :arg0 => false }
		go expect, args, spec
	end

	def test_boolean_on
		args = %W[ --arg0 ]
		spec = [ { name: :arg0, boolean: true } ]
		expect = { :arg0 => true }
		go expect, args, spec
	end

	# ---------------------------------------- switch

	def test_switch_missing_no_default
		args = %W[ ]
		spec = [ { name: :arg0, options: [ :opt0, :opt1 ] } ]
		expect = { :arg0 => nil }
		go expect, args, spec
	end

	def test_switch_missing_default
		args = %W[ ]
		spec = [ { name: :arg0, default: :opt0, options: [ :opt1 ] } ]
		expect = { :arg0 => :opt0 }
		go expect, args, spec
	end

	def test_switch_present_no_default
		args = %W[ --opt1 ]
		spec = [ { name: :arg0, options: [ :opt0, :opt1 ] } ]
		expect = { :arg0 => :opt1 }
		go expect, args, spec
	end

	def test_switch_present_default
		args = %W[ --opt1 ]
		spec = [ { name: :arg0, default: :opt0, options: [ :opt1 ] } ]
		expect = { :arg0 => :opt1 }
		go expect, args, spec
	end

	def test_switch_multiple_no_default
		# TODO
	end

	def test_switch_multiple_default
		# TODO
	end

end
