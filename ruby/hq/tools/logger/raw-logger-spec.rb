require "hq/tools/logger/raw-logger"
require "hq/tools/logger/logger-examples"

class HQ::Tools::Logger
describe RawLogger do

	include_examples "a logger"

	context "#output" do

		it "outputs JSON" do

			json = output_for(sample_log_with_content)

			MultiJson.load(json).should == {
				"mode" => "normal",
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
end
