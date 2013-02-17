require "hq/tools/logger/logger-examples"
require "hq/tools/logger/text-logger"

describe HQ::Tools::Logger::TextLogger do

	include_examples "a logger"

	context "#output" do

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

		it "command with output" do

			output_for(sample_command_with_output).should == [
				"hostname debug: |text\n",
				"hostname debug: |  output 1\n",
				"hostname debug: |  output 2\n",
			].join

		end

		it "command without output" do

			output_for(sample_command_without_output).should == [
				"hostname debug: |text\n",
			].join

		end

		it "command-output" do

			output_for(sample_command_output).should == [
				"hostname debug: |  text\n",
			].join

		end

	end

	context "#valid_modes" do

		it "returns [ :normal, :partial ]" do
			subject.valid_modes.should == [ :normal, :partial ]
		end

	end

end
