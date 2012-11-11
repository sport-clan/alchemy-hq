require "hq/engine"

class HQ::Engine::API

	attr_accessor :mvcc

	def transaction_begin
		mvcc.transaction_begin
	end

	def transaction_commit transaction_id
		mvcc.transaction_commit transaction_id
	end

	def transaction_rollback transaction_id
		mvcc.transaction_rollback transaction_id
	end

end
