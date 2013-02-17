require "hq/tools/logger/ansi-logger"
require "hq/tools/logger/logger-examples"

describe HQ::Tools::Logger::AnsiLogger do

	include_examples "a logger"

	context "#output" do

		def ansi_line colour, text
			return [
				HQ::Tools::Logger::AnsiLogger::ANSI_CODES[:bold],
				HQ::Tools::Logger::AnsiLogger::ANSI_CODES[:blue],
				"hostname:",
				" ",
				HQ::Tools::Logger::AnsiLogger::ANSI_CODES[colour],
				text,
				HQ::Tools::Logger::AnsiLogger::ANSI_CODES[:normal],
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

		it "command with output" do

			output_for(sample_command_with_output).should == [
				ansi_line(:cyan, "|text"),
				ansi_line(:normal, "|  output 1"),
				ansi_line(:normal, "|  output 2"),
			].join

		end

		it "command without output" do

			output_for(sample_command_without_output).should == [
				ansi_line(:cyan, "|text"),
			].join

		end

		it "command-output" do

			output_for(sample_command_output).should == [
				ansi_line(:normal, "|  text"),
			].join

		end

	end

	context "#valid_modes" do

		it "returns [ :normal, :partial ]" do
			subject.valid_modes.should == [ :normal, :partial ]
		end

	end

end
