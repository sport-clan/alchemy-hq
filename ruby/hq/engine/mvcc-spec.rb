require "hq/engine/mvcc"

describe HQ::Engine::MVCC do

	context "#transactions" do

		it "returns all current transactions" do

			tx_id_1 =
				subject.transaction_begin

			tx_id_2 =
				subject.transaction_begin

			subject.transactions.keys.should ==
				[ tx_id_1, tx_id_2 ]

		end

	end

	context "#transaction_begin" do

		it "creates a new transaction" do

			tx_id =
				subject.transaction_begin

			subject.transactions.size.should == 1

			subject.transactions.keys.should == [ tx_id ]

		end

		it "returns a random transaction id" do

			ret = subject.transaction_begin

			ret.should match /^[a-z]{16}$/

		end

	end

	context "#transaction_commit" do

		it "removes the specified transaction" do

			subject.transactions = {
				"transaction id" => {},
			}

			subject.transaction_commit \
				"transaction id"

			subject.transactions.keys
				.should_not include "transaction id"

		end

	end

	context "#transaction_rollback" do

		it "removes the specified transaction" do

			subject.transactions = {
				"transaction id" => {},
			}

			subject.transaction_rollback \
				"transaction id"

			subject.transactions.keys
				.should_not include "transaction id"

		end

	end

end
