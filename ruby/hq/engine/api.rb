module HQ
module Engine
class API

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

	def data_store \
		transaction_id,
		record_id,
		record_value

		mvcc.data_store \
			transaction_id,
			record_id,
			record_value

	end

	def data_retrieve \
		transaction_id,
		record_id

		return \
			mvcc.data_retrieve \
				transaction_id,
				record_id

	end

end
end
end
