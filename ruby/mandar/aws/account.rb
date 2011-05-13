require "thread"

class Mandar::AWS::Account

	attr_accessor :name
	attr_accessor :access_key_id
	attr_accessor :secret_access_key
	attr_accessor :user_id

	def initialize()
	end

	def hash()
		return @hash if @hash
		return [ name, access_key_id, secret_access_key, user_id ].hash
	end

	def freeze()
		@hash = hash
		super
	end

	def eql?(other)
		return false unless other.is_a self
		return false unless name == other.name
		return false unless access_key_id == other.access_key_id
		return false unless secret_access_key == other.secret_access_key
		return false unless user_id == other.user_id
		return true
	end
end
