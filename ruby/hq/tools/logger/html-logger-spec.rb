require "hq/tools/logger/html-logger"
require "hq/tools/logger/logger-examples"

describe HQ::Tools::Logger::HtmlLogger do

	include_examples "a logger"

	context "#output" do

		def output_for content

			string_io =
				StringIO.new

			subject.output \
				content,
				{ out: string_io, prefix: "|" }

			return string_io.string

		end

		it "log without content" do

			output_for(sample_log_without_content).should == [
				"|<div class=\"hq-log-item hq-log-item-debug\">\n",
				"|\t<div class=\"hq-log-head\">\n",
				"|\t\t<div class=\"hq-log-hostname\">hostname</div>\n",
				"|\t\t<div class=\"hq-log-text\">text</div>\n",
				"|\t</div>\n",
				"|</div>\n",
			].join

		end

		it "log with empty content" do

			output_for(sample_log_with_empty_content).should == [
				"|<div class=\"hq-log-item hq-log-item-debug\">\n",
				"|\t<div class=\"hq-log-head\">\n",
				"|\t\t<div class=\"hq-log-hostname\">hostname</div>\n",
				"|\t\t<div class=\"hq-log-text\">text</div>\n",
				"|\t</div>\n",
				"|</div>\n",
			].join

		end

		it "log with content" do

			output_for(sample_log_with_content).should == [
				"|<div class=\"hq-log-item hq-log-item-debug\">\n",
				"|\t<div class=\"hq-log-head\">\n",
				"|\t\t<div class=\"hq-log-hostname\">hostname</div>\n",
				"|\t\t<div class=\"hq-log-text\">text</div>\n",
				"|\t</div>\n",
				"|\t<div class=\"hq-log-content\">\n",
				"|\t\t<div class=\"hq-log-simple\">content 1</div>\n",
				"|\t\t<div class=\"hq-log-simple\">content 2</div>\n",
				"|\t</div>\n",
				"|</div>\n",
			].join

		end

		it "exception" do

			output_for(sample_exception).should == [
				"|<div class=\"hq-log-item hq-log-item-debug\">\n",
				"|\t<div class=\"hq-log-head\">\n",
				"|\t\t<div class=\"hq-log-hostname\">hostname</div>\n",
				"|\t\t<div class=\"hq-log-text\">text</div>\n",
				"|\t</div>\n",
				"|\t<div class=\"hq-log-content\">\n",
				"|\t\t<div class=\"hq-log-exception\">\n",
				"|\t\t\t<div class=\"hq-log-exception-message\">message</div>\n",
				"|\t\t\t<div class=\"hq-log-exception-backtrace\">\n",
				"|\t\t\t\t<div class=\"hq-log-exception-backtrace-line\">" +
					"backtrace 1</div>\n",
				"|\t\t\t\t<div class=\"hq-log-exception-backtrace-line\">" +
					"backtrace 2</div>\n",
				"|\t\t\t</div>\n",
				"|\t\t</div>\n",
				"|\t</div>\n",
				"|</div>\n",
			].join

		end

		it "diff" do

			output_for(sample_diff).should == [
				"|<div class=\"hq-log-item hq-log-item-debug\">\n",
				"|\t<div class=\"hq-log-head\">\n",
				"|\t\t<div class=\"hq-log-hostname\">hostname</div>\n",
				"|\t\t<div class=\"hq-log-text\">text</div>\n",
				"|\t</div>\n",
				"|\t<div class=\"hq-log-content\">\n",
				"|\t\t<div class=\"hq-log-diff\">\n",
				"|\t\t\t<div class=\"hq-log-diff-minus-minus-minus\">diff 1</div>\n",
				"|\t\t\t<div class=\"hq-log-diff-plus-plus-plus\">diff 2</div>\n",
				"|\t\t\t<div class=\"hq-log-diff-at-at\">diff 3</div>\n",
				"|\t\t\t<div class=\"hq-log-diff-minus\">diff 4</div>\n",
				"|\t\t\t<div class=\"hq-log-diff-plus\">diff 5</div>\n",
				"|\t\t\t<div class=\"hq-log-diff-else\">diff 6</div>\n",
				"|\t\t</div>\n",
				"|\t</div>\n",
				"|</div>\n",
			].join

		end

		it "command with output" do

			output_for(sample_command_with_output).should == [
				"|<div class=\"hq-log-item hq-log-item-debug\">\n",
				"|\t<div class=\"hq-log-head\">\n",
				"|\t\t<div class=\"hq-log-hostname\">hostname</div>\n",
				"|\t\t<div class=\"hq-log-text\">text</div>\n",
				"|\t</div>\n",
				"|\t<div class=\"hq-log-content\">\n",
				"|\t\t<div class=\"hq-log-command-output\">\n",
				"|\t\t\t<div class=\"hq-log-command-output-line\">output 1</div>\n",
				"|\t\t\t<div class=\"hq-log-command-output-line\">output 2</div>\n",
				"|\t\t</div>\n",
				"|\t</div>\n",
				"|</div>\n",
			].join

		end

		it "command without output" do

			output_for(sample_command_without_output).should == [
				"|<div class=\"hq-log-item hq-log-item-debug\">\n",
				"|\t<div class=\"hq-log-head\">\n",
				"|\t\t<div class=\"hq-log-hostname\">hostname</div>\n",
				"|\t\t<div class=\"hq-log-text\">text</div>\n",
				"|\t</div>\n",
				"|</div>\n",
			].join

		end

	end

	context "#valid_modes" do

		it "returns [ :normal, :complete ]" do
			subject.valid_modes.should == [ :normal, :complete ]
		end

	end

end
