require "hq/systools/rrd/check-recent-script"

module HQ::SysTools::RRD
describe CheckRecentScript do

	before do
		require "RRD"
		RRD.stub(:info).and_return({ "last_update" => 99 })
		Time.stub(:now).and_return(Time.at(100))
		subject.stdout = StringIO.new
		subject.stderr = StringIO.new
	end

	before do
		subject.args = [
			[ "--warning", "10" ],
			[ "--critical", "60" ],
			[ "--name", "Name" ],
			[ "file-1", "file-2" ],
		]
	end

	it "runs fine with a minimum set of parameters" do
		subject.main
	end

	it "calls RRD.info for each filename" do
		RRD.should_receive(:info).with("file-1")
		RRD.should_receive(:info).with("file-2")
		subject.main
	end

	def output
		subject.stdout.string
	end

	def self.check_status status
		it "returns #{status}" do
			subject.status.should == status
		end
	end

	def self.check_output string
		it "outputs '#{string}'" do
			subject.stdout.string.strip.should == string
		end
	end

	context "when both are ok" do

		before do
			subject.main
		end

		check_output "Name OK: 2 graphs, oldest is 1s"
		check_status 0

	end

	context "when one is warning and the other is ok" do

		before do
			RRD.should_receive(:info).with("file-1")
				.and_return({ "last_update" => 80 })
			subject.main
		end

		check_output "Name WARNING: 2 graphs, 1 warning, oldest is 20s"
		check_status 1

	end

	context "when one is warning and the other is critical" do

		before do
			RRD.should_receive(:info).with("file-1")
				.and_return({ "last_update" => 80 })
			RRD.should_receive(:info).with("file-2")
				.and_return({ "last_update" => 10 })
			subject.main
		end

		check_output "Name CRITICAL: 2 graphs, 1 critical, 1 warning, oldest is 90s"
		check_status 2

	end

end
end
