require "pp"
require "tempfile"

require "rubygems"

gem "test-unit"
require "test/unit"

module Mandar end
module Mandar::Tools end

require "mandar/tools/getopt"

class GetoptTest < Test::Unit::TestCase

	def setup
	end

	def go expect, args, spec
		ret, remain = Mandar::Tools::Getopt.process args, spec
		assert_equal expect, ret
	end

	def go_error args, spec, message
		Tempfile.open "getopt-test" do |tmp|
			$stderr.reopen tmp.path, "w"
			assert_raise(Mandar::Tools::GetoptError) do
				Mandar::Tools::Getopt.process args, spec
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

	# ---------------------------------------- required with conversion

	def test_required_conversion_symbol
		args = [ "--arg-0", "123" ]
		spec = [ { name: :arg_0, required: true, regex: /[0-9]+/, convert: :to_i } ]
		expect = { :arg_0 => 123 }
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

end
