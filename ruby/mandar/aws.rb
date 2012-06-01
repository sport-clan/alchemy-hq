module Mandar::AWS

	def self.connect endpoint, access_key_id, secret_access_key, version

		aws_account =
			Mandar::AWS::Account.new

		aws_account.access_key_id =
			access_key_id

		aws_account.secret_access_key =
			secret_access_key

		aws_client =
			Mandar::AWS::Client.new \
				aws_account,
				endpoint,
				version

		aws_client.default_prefix = "a"

		return aws_client
	end

end

require "mandar/aws/account"
require "mandar/aws/client"
