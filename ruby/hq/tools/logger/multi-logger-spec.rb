require "hq/tools/logger/multi-logger"

describe HQ::Tools::Logger::MultiLogger do

	context "#output" do

		it "outputs to all added loggers" do

			logger_1 = double "logger 1"
			logger_2 = double "logger 2"

			subject.add_logger logger_1
			subject.add_logger logger_2

			logger_1.should_receive(:output).with(:a, :b, :c)
			logger_2.should_receive(:output).with(:a, :b, :c)

			subject.output :a, :b, :c

		end

	end

end
