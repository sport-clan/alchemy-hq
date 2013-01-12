require "hq/engine"

class HQ::Engine::MVCC

	attr_accessor :transactions

	def initialize
		@transactions = {}
	end

	def generate_transaction_id
		chars = (?a..?z).to_a
		return (0...20).map { chars.sample }.join
	end

	def transaction_begin

		tx_id =
			generate_transaction_id

		@transactions[tx_id] =
			{
				state: :begun,
				changes: {},
			}

		return tx_id

	end

	def transaction_commit transaction_id

		transaction =
			@transactions[transaction_id]

		transaction[:state] =
			:committed

	end

	def transaction_rollback transaction_id

		transaction =
			@transactions[transaction_id]

		transaction[:state] =
			:rolled_back

	end

	def get_transaction_info transaction_id

		transaction =
			@transactions[transaction_id]

		unless transaction
			return nil
		end

		transaction_info = {
			state: transaction[:state],
		}

		return transaction_info

	end

	def data_store \
		transaction_id,
		record_id,
		record_value

		transaction =
			@transactions[transaction_id]

		transaction[:changes][record_id] =
			record_value

	end

	def data_retrieve \
		transaction_id,
		record_id

		transaction =
			@transactions[transaction_id]

		return \
			transaction[:changes][record_id]

	end

end
