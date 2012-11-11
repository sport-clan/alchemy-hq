require "hq/engine/api"

describe HQ::Engine::API do

	let(:mvcc) { double :mvcc }

	before do
		subject.mvcc = mvcc
	end

	it "has a property named :mvcc" do
		subject.mvcc = "some value"
		subject.mvcc.should == "some value"
	end

	context "#transaction_begin" do

		it "calls mvcc.transaction_begin" do

			mvcc.should_receive(:transaction_begin)

			subject.transaction_begin

		end

		it "returns the transaction id" do

			mvcc.stub(:transaction_begin)
				.and_return("transaction id")

			subject.transaction_begin.should ==
				"transaction id"

		end

	end

	context "#transaction_commit" do

		it "calls mvcc.transaction_commit" do

			mvcc.should_receive(:transaction_commit)
				.with("transaction id")

			subject.transaction_commit \
				"transaction id"

		end

	end

	context "#transaction_rollback" do

		it "calls mvcc.transaction_rollback" do

			mvcc.should_receive(:transaction_rollback)
				.with("transaction id")

			subject.transaction_rollback \
				"transaction id"

		end

	end

end
