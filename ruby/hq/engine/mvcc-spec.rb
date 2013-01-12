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

		it "returns a transaction id formed of twenty lower case letters" do

			tx_id =
				subject.transaction_begin

			tx_id.should \
				match /^[a-z]{20}$/

		end

	end

	context "#transaction_commit" do

		it "changes the specified transaction's state to :committed" do

			subject.transactions = {
				"transaction id" => {},
			}

			subject.transaction_commit \
				"transaction id"

			transaction =
				subject.transactions["transaction id"]

			transaction[:state]
				.should == :committed

		end

	end

	context "#transaction_rollback" do

		it "changes the specified transaction's state to :rolled_back" do

			subject.transactions = {
				"transaction id" => {},
			}

			subject.transaction_rollback \
				"transaction id"

			transaction =
				subject.transactions["transaction id"]

			transaction[:state]
				.should == :rolled_back

		end

	end

	context "#get_transaction_info" do

		it "returns nil if the transaction id is invalid" do

			subject.transactions = {
				"real transaction id" => {},
			}

			transaction_info =
				subject.get_transaction_info \
					"imaginary transaction_id"

			transaction_info.should \
				be_nil

		end

		it "returns a hash with transaction information if the transaction " +
			"id is valid" do

			subject.transactions = {
				"transaction id" => {},
			}

			transaction_info =
				subject.get_transaction_info \
					"transaction id"

			transaction_info.should \
				be_a Hash

		end

		it "returns a state of :begun for an active transaction" do

			transaction_id =
				subject.transaction_begin

			transaction_info =
				subject.get_transaction_info \
					transaction_id

			transaction_info[:state].should \
				== :begun

		end

		it "returns a state of :committed for a committed transaction" do

			transaction_id =
				subject.transaction_begin

			subject.transaction_commit \
				transaction_id

			transaction_info =
				subject.get_transaction_info \
					transaction_id

			transaction_info[:state].should \
				== :committed

		end

	end

	context "#data_store" do

		it "stores the provided value in the specified transaction" do

			transaction_id =
				subject.transaction_begin

			subject.data_store \
				transaction_id,
				"record id",
				"record value"

			transaction =
				subject.transactions[transaction_id]

			transaction[:changes]["record id"]
				.should == "record value"

		end

	end

	context "#data_retrieve" do

		it "returns the specified record from the specified transaction" do

			subject.transactions = {
				"transaction id" => {
					changes: {
						"record id" => "record value",
					}
				},
			}

			record_value =
				subject.data_retrieve \
					"transaction id",
					"record id"

			record_value
				.should == "record value"

		end

	end

end
