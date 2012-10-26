require "mandar"

describe Mandar::Support::Ubuntu do

	describe "#initctl_auto" do

		before do

			Mandar
				.stub(:debug)

			Mandar
				.stub(:notice)

			Mandar::Support::Ubuntu
				.stub(:sleep)

			Mandar::Support::Core
				.stub(:shell)

			Mandar::Support::Core
				.stub(:shell_real)
				.and_return({ status: 0, output: [ "service start/" ] })

			Mandar::Deploy::Flag
				.stub(:check)
				.and_return(true)

			Mandar::Deploy::Flag
				.stub(:clear)

		end

		it "notifies checking service status to debug" do

			Mandar
				.should_receive(:debug)
				.with("checking status of service")

			subject.initctl_auto "service", true, "restart"

		end

		it "runs initctl to query the service status" do

			Mandar::Support::Core
				.should_receive(:shell_real)
				.with("initctl status service")

			subject.initctl_auto "service", true, "restart"

		end

		it "raises an error if the command fails" do

			Mandar::Support::Core
				.should_receive(:shell_real)
				.with("initctl status service")
				.and_return({ status: 1 })

			expect do
				subject.initctl_auto "service", true, "restart"
			end.to raise_error \
				RuntimeError,
				"initctl status service returned 1"

		end

		it "raises an error if the output is invalid" do

			Mandar::Support::Core
				.should_receive(:shell_real)
				.with("initctl status service")
				.and_return({ status: 0, output: [ "blah" ] })

			expect do
				subject.initctl_auto "service", true, "restart"
			end.to raise_error \
				RuntimeError,
				"Error"

		end

		context "when the service needs restarting" do

			it "writes a restarting message to notice" do

				Mandar
					.should_receive(:notice)
					.with("restarting service")

				subject.initctl_auto "service", true, "restart"

			end

			it "runs initctl to stop the service" do

				Mandar::Support::Core
					.should_receive(:shell)
					.with("initctl stop service")

				subject.initctl_auto "service", true, "restart"

			end

			it "sleeps for one second" do

				subject
					.should_receive(:sleep)
					.with(1)

				subject.initctl_auto "service", true, "restart"

			end

			it "runs initctl to start the service" do

				Mandar::Support::Core
					.should_receive(:shell)
					.with("initctl start service")

				subject.initctl_auto "service", true, "restart"

			end

		end

		context "when the service needs starting" do

			before do

				Mandar::Support::Core
					.stub(:shell_real)
					.and_return({ status: 0, output: [ "service stop/" ] })

			end

			it "writes a starting message to notice" do

				Mandar
					.should_receive(:notice)
					.with("starting service")

				subject.initctl_auto "service", true, "restart"

			end

			it "runs initctl to start the service" do

				Mandar::Support::Core
					.should_receive(:shell)
					.with("initctl start service")

				subject.initctl_auto "service", true, "restart"

			end

		end

		context "when the service needs stopping" do

			it "writes a stopping message to notice" do

				Mandar
					.should_receive(:notice)
					.with("stopping service")

				subject.initctl_auto "service", false, "restart"

			end

			it "runs initctl to stop the service" do

				Mandar::Support::Core
					.should_receive(:shell)
					.with("initctl stop service")

				subject.initctl_auto "service", false, "restart"

			end

		end

		context "when the restart flag is provided" do

			it "clears the restart flag" do

				Mandar::Deploy::Flag
					.should_receive(:clear)
					.with("restart")

				subject.initctl_auto "service", true, "restart"

			end

		end

		context "when the restart flag is not provided" do

			it "does not clear the restart flag" do

				Mandar::Deploy::Flag
					.should_not_receive(:clear)
					.with("restart")

				subject.initctl_auto "service", true, nil

			end

		end

	end

	describe "#command_initctl_auto" do

		def create_elem running
			elem = XML::Node.new "initctl-auto"
			elem.attributes["service"] = "service"
			elem.attributes["running"] = running
			elem.attributes["restart-flag"] = "restart"
			return elem
		end

		context "with running set to yes" do

			it "calls initctl_auto with running set to true" do

				subject
					.should_receive(:initctl_auto)
					.with("service", true, "restart")

				subject.command_initctl_auto \
					create_elem("yes")

			end

		end

		context "with running set to no" do

			it "calls initctl_auto with running set to false" do

				subject
					.should_receive(:initctl_auto)
					.with("service", false, "restart")

				subject.command_initctl_auto \
					create_elem("no")

			end

		end

		context "with running not set correctly" do

			it "throws an error" do

				expect do
					subject.command_initctl_auto \
						create_elem("blah")
				end.to raise_error \
					RuntimeError,
					"Error"

			end

		end

	end

end
