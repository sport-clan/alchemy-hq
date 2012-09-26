module Mandar::Tools::Client

	def self.client_config_elem

		return @client_config_elem if @client_config_elem

		client_config_doc =
			XML::Document.file "#{CONFIG}/etc/client-config.xml"

		@client_config_elem =
			client_config_doc.root

		return @client_config_elem

	end

	def self.hq_client server_name

		server_name_xpath =
			Mandar::Tools::Escape.xpath server_name

		server_elem =
			client_config_elem.find_first \
				"server [@name = #{server_name_xpath}]"

		server_elem \
			or raise "<server name=\"#{server_name}\"> not found in " +
				"etc/client-config.xml"

		@hq_client =
			Mandar::Tools::MandarClient.new \
				server_elem.attributes["url"],
				server_elem.attributes["username"],
				server_elem.attributes["password"]

		return @hq_client

	end

	def self.aws_client hq_client, account_name, region

		aws_account_rec =
			hq_client.stager_get \
				"aws-account",
				account_name

		aws_endpoint =
			"ec2.#{region}.amazonaws.com"

		aws_account =
			Mandar::AWS::Account.new

		aws_account.name =
			aws_account_rec["name"]

		aws_account.access_key_id =
			aws_account_rec["access-key-id"]

		aws_account.secret_access_key =
			aws_account_rec["secret-access-key"]

		aws_client =
			Mandar::AWS::Client.new \
				aws_account,
				aws_endpoint,
				"2012-08-15"

		aws_client.default_prefix = "a"

		return aws_client

	end

end
