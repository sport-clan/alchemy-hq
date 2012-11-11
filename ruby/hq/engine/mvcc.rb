require "hq/engine"

class HQ::Engine::MVCC

	attr_accessor :transactions

	def initialize
		@transactions = {}
	end

	def generate_transaction_id
		chars = (?a..?z).to_a
		return (0...16).map { chars.sample }.join
	end

	def transaction_begin

		tx_id =
			generate_transaction_id

		@transactions[tx_id] =
			{}

		return tx_id

	end

	def transaction_commit transaction_id
		@transactions.delete transaction_id
	end

	def transaction_rollback transaction_id
		@transactions.delete transaction_id
	end

end
