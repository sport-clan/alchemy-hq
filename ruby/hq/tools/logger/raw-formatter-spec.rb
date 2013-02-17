require "hq/tools/logger/raw-formatter"
require "hq/tools/logger/formatter-examples"

describe HQ::Tools::Logger::RawFormatter do

	include_examples "a log formatter"

	context "#output_raw" do

		def output_for content

			string_io =
				StringIO.new

			subject.output \
				content,
				{ out: string_io, mode: :mode }

			return string_io.string

		end

		it "outputs JSON" do

			json = output_for(sample_log_with_content)

			MultiJson.load(json).should == {
				"mode" => "mode",
				"content" => [
					{
						"type" => "log",
						"level" => "debug",
						"hostname" => "hostname",
						"text" => "text",
						"content" => [
							"content 1",
							"content 2",
						],
					},
				],
			}

		end

	end

	context "#valid_modes" do

		it "returns [ :normal, :partial ]" do
			subject.valid_modes.should == [ :normal, :partial ]
		end

	end

end
