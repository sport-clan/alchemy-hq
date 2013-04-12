require "hq/systools/ec2/ec2-snapshot-create"

module HQ::SysTools::EC2

	describe Ec2SnapshotCreateScript do

		before :all do
			require "xml"
		end

		let :config_xml do
			XML::Document.string %q{

				<ec2-snapshots-config
					lock="lock-file"
					state="state-file">

					<aws-account
						name="account-1"
						access-key-id="access-key-id-1"
						secret-access-key="secret-access-key-1"/>

					<aws-account
						name="account-2"
						access-key-id="access-key-id-2"
						secret-access-key="secret-access-key-2"/>

					<ec2-region
						name="region-1"
						endpoint="endpoint-1"/>

					<ec2-region
						name="region-2"
						endpoint="endpoint-2"/>

					<ec2-availability-zone
						name="zone-1"
						region="region-1"/>

					<ec2-availability-zone
						name="zone-2"
						region="region-1"/>

					<ec2-availability-zone
						name="zone-3"
						region="region-2"/>

					<ec2-availability-zone
						name="zone-3"
						region="region-2"/>

					<volume
						host="host-1"
						minute="1"
						aws-account="account-1"
						availability-zone="zone-1"
						volume-id="volume-1"
						policy="low"
						frequency="hourly"/>

					<volume
						host="host-2"
						minute="1"
						aws-account="account-1"
						availability-zone="zone-2"
						volume-id="volume-2"
						policy="medium"
						frequency="daily"
						daily-hour="17"/>

					<volume
						host="host-3"
						minute="2"
						aws-account="account-1"
						availability-zone="zone-1"
						volume-id="volume-3"
						policy="low"
						frequency="hourly"/>

					<volume
						host="host-4"
						minute="1"
						aws-account="account-1"
						availability-zone="zone-3"
						volume-id="volume-4"
						policy="low"
						frequency="hourly"/>

				</ec2-snapshots-config>

			}
		end

		let :script do
			Ec2SnapshotCreateScript.new
		end

		let :aws_client do
			doube "aws_client"
		end

		before :each do

			$stderr.stub(:puts)

			XML::Document.stub(:file) do |filename|
				config_xml
			end

		end

		describe "#main" do

			context "with no args" do

				before :each do
					script.args = []
				end

				it "prints an error" do

					$stderr
						.should_receive(:puts)
						.with("Syntax error")

					script.main

				end

				it "exits with 1" do
					script.main
					script.exit_code.should == 1
				end

			end

			context "with valid args" do

				before :each do

					script.args = [ "config.xml" ]

					script.stub(:do_minute)

					Time.stub(:now) do
						Time.at 1348679727
					end

					File.stub(:open)

					HQ::Tools::Lock
						.stub(:lock)
						.and_yield

				end

				it "reads the config file" do

					XML::Document
						.should_receive(:file)
						.with("config.xml")

					script.main

				end

				it "sets @config_elem" do

					script.main

					script
						.instance_variable_get(:@config_elem)
						.should == config_xml.root

				end

				it "checks the current time" do

					Time.should_receive(:now)

					script.main

				end

				it "checks if the state file exists" do

					File.should_receive(:exist?)
						.with("state-file")

					script.main

				end

				context "with no existing state" do

					before :each do

						File.stub(:open)

						File.should_receive(:exist?)
							.with("state-file")
							.and_return(false)

					end

					it "writes the state file" do

						file = double("file")

						File.should_receive(:open)
							.with("state-file", "w")
							.and_yield(file)

						file.should_receive(:print)
							.with("15\n")

						script.main

					end

					it "does not obtain a lock" do

						HQ::Tools::Lock
							.should_not_receive(:lock)
							.with("lock-file")

						script.main

					end

					it "does not call do_minute" do

						script
							.should_not_receive(:do_minute)

						script.main

					end

				end

				context "with existing state" do

					before :each do

						File.should_receive(:exist?)
							.with("state-file")
							.and_return(true)

					end

					it "reads the file" do

						File.should_receive(:read)
							.with("state-file")

						script.main

					end

					context "when it is the state minute" do

						before :each do

							File.should_receive(:read)
								.with("state-file")
								.and_return("15\n")

						end

						it "does not obtain a lock" do

							HQ::Tools::Lock
								.should_not_receive(:lock)
								.with("lock-file")

							script.main

						end

						it "does not call do_minute" do

							script
								.should_not_receive(:do_minute)

							script.main

						end

					end

					context "when it is one past the state minute" do

						before :each do

							File.should_receive(:read)
								.with("state-file")
								.and_return("14\n")

						end

						it "obtains a lock" do

							HQ::Tools::Lock
								.should_receive(:lock)
								.with("lock-file")

							script.main

						end

						it "calls #do_minute once" do

							script
								.should_receive(:do_minute)
								.with(17, 14)
								.once

							script.main

						end

						it "updates the state file" do

							file = double "file"

							File.should_receive(:open)
								.with("state-file", "w")
								.and_yield(file)

							file.should_receive(:print)
								.with("15\n")

							script.main

						end

					end

					context "when it is thirty past the state minute" do

						before :each do

							File.should_receive(:read)
								.with("state-file")
								.and_return("45\n")

						end

						it "obtains a lock" do

							HQ::Tools::Lock
								.should_receive(:lock)
								.with("lock-file")

							script.main

						end

						it "calls #do_minute thirty times" do

							# check the hour is set correctly as well

							script
								.should_receive(:do_minute)
								.with(16, 45)
								.once
								.ordered

							script
								.should_receive(:do_minute)
								.exactly(13).times

							script
								.should_receive(:do_minute)
								.with(16, 59)
								.once

							script
								.should_receive(:do_minute)
								.with(17, 0)
								.once

							script
								.should_receive(:do_minute)
								.exactly(13).times

							script
								.should_receive(:do_minute)
								.with(17, 14)
								.once

							script.main

						end

						it "updates the state file thirty times" do

							File.should_receive(:open)
								.with("state-file", "w")
								.exactly(30).times

							script.main

						end

					end

				end

			end

		end # describe "#main"

		describe "#do_minute" do

			before :each do

				script.instance_variable_set \
					:@config_elem,
					config_xml.root

			end

			it "calls #do_account_region for every account and region" do

				script
					.should_receive(:do_account_region)
					.with(
						17, 1,
						"account-1",
						"access-key-id-1",
						"secret-access-key-1",
						"region-1",
						"endpoint-1")

				script
					.should_receive(:do_account_region)
					.with(
						17, 1,
						"account-1",
						"access-key-id-1",
						"secret-access-key-1",
						"region-2",
						"endpoint-2")

				script
					.should_receive(:do_account_region)
					.with(
						17, 1,
						"account-2",
						"access-key-id-2",
						"secret-access-key-2",
						"region-1",
						"endpoint-1")

				script
					.should_receive(:do_account_region)
					.with(
						17, 1,
						"account-2",
						"access-key-id-2",
						"secret-access-key-2",
						"region-2",
						"endpoint-2")

				script.do_minute 17, 1

			end

		end # describe "#do_minute"

		describe "#do_account_region" do

			before :each do

				@aws_client = double "aws_client"
				@aws_client.stub(:default_prefix=)

				script.stub(:do_volume)

			end

			let :aws_client do
				@aws_client
			end

			before :each do

				script.instance_variable_set \
					:@config_elem,
					config_xml.root

				Mandar::AWS::Client
					.stub(:new)
					.and_return(aws_client)

			end

			it "creates an aws client" do

				aws_account = Mandar::AWS::Account.new
				aws_account.name = "account-1"
				aws_account.access_key_id = "access-key-id-1"
				aws_account.secret_access_key = "secret-access-key-1"

				Mandar::AWS::Client
					.should_receive(:new)
					.with(aws_account, "endpoint-1", "2010-08-31")

				aws_client
					.should_receive(:default_prefix=)
					.with("a")

				script.do_account_region \
					17, 1,
					"account-1",
					"access-key-id-1",
					"secret-access-key-1",
					"region-1",
					"endpoint-1"

			end

			context "during the daily hour" do

				it "calls #do_volume for matching volumes" do

					script
						.should_receive(:do_volume)
						.with(aws_client, "host-1", "volume-1")

					script
						.should_receive(:do_volume)
						.with(aws_client, "host-2", "volume-2")

					script
						.should_not_receive(:do_volume)
						.with(aws_client, "host-3", "volume-3")

					script
						.should_not_receive(:do_volume)
						.with(aws_client, "host-4", "volume-4")

					script.do_account_region \
						17, 1,
						"account-1",
						"access-key-id-1",
						"secret-access-key-1",
						"region-1",
						"endpoint-1"

				end

			end

			context "outside the daily hour" do

				it "calls #do_volume for matching volumes" do

					script
						.should_receive(:do_volume)
						.with(aws_client, "host-1", "volume-1")

					script
						.should_not_receive(:do_volume)
						.with(aws_client, "host-2", "volume-2")

					script
						.should_not_receive(:do_volume)
						.with(aws_client, "host-3", "volume-3")

					script
						.should_not_receive(:do_volume)
						.with(aws_client, "host-4", "volume-4")

					script.do_account_region \
						16, 1,
						"account-1",
						"access-key-id-1",
						"secret-access-key-1",
						"region-1",
						"endpoint-1"

				end

			end

		end # describe "#do_account_region"

		describe "#do_volume" do

			before :each do

				@aws_client = double "aws_client"

				script.stub(:debug)
				script.stub(:sleep)

			end

			let :aws_client do
				@aws_client
			end

			let :normal_response do
				doc = XML::Document.string "
					<response xmlns='http://blah.com/ns'>
						<snapshotId>snapshot-1</snapshotId>
					</response>
				"
				doc.root.namespaces.default_prefix = "a"
				doc
			end

			before :each do

				aws_client
					.stub(:create_snapshot)
					.and_return(normal_response)

			end

			it "creates the snapshot" do

				aws_client
					.should_receive(:create_snapshot)
					.with({
						:volume_id => "volume-1",
						:description => "automated backup of host-1"})

				script.do_volume \
					aws_client,
					"host-1",
					"volume-1"

			end

			it "calls #debug with the snapshot id" do

				script
					.should_receive(:debug)
					.with("snapshot for host-1 volume-1: snapshot-1")

				script.do_volume \
					aws_client,
					"host-1",
					"volume-1"

			end

			context "with an error" do

				before :each do

					aws_client
						.stub(:create_snapshot)
						.and_raise(StandardError.new("error"))

				end

				it "prints a message to stderr" do

					$stderr
						.should_receive(:puts)
						.with("error creating snapshot for host-1 " +
							"volume-1: error")

					script.do_volume \
						aws_client,
						"host-1",
						"volume-1"

				end

				it "sleeps one second" do

					script
						.should_receive(:sleep)
						.with(1)

					script.do_volume \
						aws_client,
						"host-1",
						"volume-1"

				end

				it "retries the call three times" do

					aws_client
						.should_receive(:create_snapshot)
						.exactly(3).times

					script.do_volume \
						aws_client,
						"host-1",
						"volume-1"

				end

				it "prints a failure to stderr after three times" do

					$stderr
						.should_receive(:puts)
						.with("snapshot for host-1 volume-1: FAILED")

					script.do_volume \
						aws_client,
						"host-1",
						"volume-1"

				end

				it "exits with an error" do

					script.do_volume \
						aws_client,
						"host-1",
						"volume-1"

					script.exit_code
						.should == 1

				end

			end

			context "with a timeout" do

				before :each do

					aws_client
						.stub(:create_snapshot)
						.and_raise(Timeout::Error.new("timeout"))

				end

				it "prints a timeout message to stderr" do

					$stderr
						.should_receive(:puts)
						.with("timeout creating snapshot for host-1 " +
							"volume-1: timeout")

					script.do_volume \
						aws_client,
						"host-1",
						"volume-1"

				end

			end

		end # describe "#do_volume"

	end # describe Ec2SnapshotCreateScript

end # module HQ::SysTools::EC2
