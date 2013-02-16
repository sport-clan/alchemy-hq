require "hq/tools/logger"

describe HQ::Tools::Logger do

	let :sample_exception do
		{
			"type" => "exception",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"message" => "message",
			"backtrace" => [
				"backtrace 1",
				"backtrace 2",
			],
		}
	end

	let :sample_log_without_content do
		{
			"type" => "log",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
		}
	end

	let :sample_log_with_empty_content do
		{
			"type" => "log",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"content" => [],
		}
	end

	let :sample_log_with_content do
		{
			"type" => "log",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"content" => [
				"content 1",
				"content 2",
			],
		}
	end

	let :sample_exception do
		{
			"type" => "exception",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"message" => "message",
			"backtrace" => [
				"backtrace 1",
				"backtrace 2",
			],
		}
	end

	let :sample_diff do
		{
			"type" => "diff",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"content" => [
				{ "type" => "diff-minus-minus-minus", "text" => "diff 1" },
				{ "type" => "diff-plus-plus-plus", "text" => "diff 2" },
				{ "type" => "diff-at-at", "text" => "diff 3" },
				{ "type" => "diff-minus", "text" => "diff 4" },
				{ "type" => "diff-plus", "text" => "diff 5" },
				{ "type" => "diff-else", "text" => "diff 6" },
			],
		}
	end

	let :sample_command do
		{
			"type" => "command",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"output" => [
				"output 1",
				"output 2",
			],
		}
	end

	context "#output_html" do

		def output_for content

			string_io =
				StringIO.new

			subject.output_html \
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

		it "command" do

			output_for(sample_command).should == [
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

	end

	context "#output_text" do

		def output_for content

			string_io =
				StringIO.new

			subject.output_text \
				content,
				{ out: string_io, prefix: "|" }

			return string_io.string

		end

		it "log without content" do

			output_for(sample_log_without_content).should == [
				"hostname debug: |text\n"
			].join

		end

		it "log with content" do

			output_for(sample_log_with_content).should == [
				"hostname debug: |text\n",
				"hostname debug: |  content 1\n",
				"hostname debug: |  content 2\n",
			].join

		end

		it "exception" do

			output_for(sample_exception).should == [
				"hostname debug: |text\n",
				"hostname debug: |  message\n",
				"hostname debug: |    backtrace 1\n",
				"hostname debug: |    backtrace 2\n",
			].join

		end

		it "diff" do

			output_for(sample_diff).should == [
				"hostname debug: |text\n",
				"hostname debug: |  diff 1\n",
				"hostname debug: |  diff 2\n",
				"hostname debug: |  diff 3\n",
				"hostname debug: |  diff 4\n",
				"hostname debug: |  diff 5\n",
				"hostname debug: |  diff 6\n",
			].join

		end

		it "command" do

			output_for(sample_command).should == [
				"hostname debug: |text\n",
				"hostname debug: |  output 1\n",
				"hostname debug: |  output 2\n",
			].join

		end

	end

	context "#output_ansi" do

		def output_for content

			string_io =
				StringIO.new

			subject.output_ansi \
				content,
				{ out: string_io, prefix: "|" }

			return string_io.string

		end

		def ansi_line colour, text
			return [
				HQ::Tools::Logger::ANSI_CODES[:bold],
				HQ::Tools::Logger::ANSI_CODES[:blue],
				"hostname:",
				" ",
				HQ::Tools::Logger::ANSI_CODES[colour],
				text,
				HQ::Tools::Logger::ANSI_CODES[:normal],
				"\n",
			]
		end

		it "log without content" do

			output_for(sample_log_without_content).should == [
				ansi_line(:cyan, "|text"),
			].flatten.join

		end

		it "log with content" do

			output_for(sample_log_with_content).should == [
				ansi_line(:cyan, "|text"),
				ansi_line(:normal, "|  content 1"),
				ansi_line(:normal, "|  content 2"),
			].flatten.join

		end

		it "exception" do

			output_for(sample_exception).should == [
				ansi_line(:cyan, "|text"),
				ansi_line(:normal, "|  message"),
				ansi_line(:normal, "|    backtrace 1"),
				ansi_line(:normal, "|    backtrace 2"),
			].join

		end

		it "diff" do

			output_for(sample_diff).should == [
				ansi_line(:cyan, "|text"),
				ansi_line(:magenta, "|  diff 1"),
				ansi_line(:magenta, "|  diff 2"),
				ansi_line(:magenta, "|  diff 3"),
				ansi_line(:red, "|  diff 4"),
				ansi_line(:blue, "|  diff 5"),
				ansi_line(:white, "|  diff 6"),
			].join

		end

		it "command" do

			output_for(sample_command).should == [
				ansi_line(:cyan, "|text"),
				ansi_line(:normal, "|  output 1"),
				ansi_line(:normal, "|  output 2"),
			].join

		end

	end

end
