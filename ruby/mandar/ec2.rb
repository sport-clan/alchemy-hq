module Mandar::EC2

	@lock = Mutex.new

	def self.connect(aws_account_name)
		(@connect_lock ||= Mutex.new).synchronize do
			@connect_map ||= {}

			# don't connect twice
			return @connect_map[aws_account_name] if @connect_map[aws_account_name]

			# this is deprecated
			Mandar.warning "using crappy aws library from rubygems"

			# load aws account
			aws_account = aws_account_load aws_account_name

			# connect
			require "AWS"
			ret = AWS::EC2::Base.new({
				:server => "ec2.amazonaws.com",
				:access_key_id => aws_account.access_key_id,
				:secret_access_key => aws_account.secret_access_key,
			})

			return @connect_map[aws_account_name] = ret
		end
	end

	@connect2_map = {}

	def self.connect2 aws_account_name, endpoint = "ec2.amazonaws.com", version = "2010-08-31"
		@lock.synchronize do

			key = "#{aws_account_name}/#{endpoint}/#{version}"
			return @connect2_map[key] if @connect2_map[key]

			aws_account = aws_account_load aws_account_name

			aws_client = Mandar::AWS::Client.new aws_account, endpoint, version
			aws_client.default_prefix = "a"

			return @connect2_map[key] = aws_client

		end
	end

	def self.aws_account_load(aws_account_name)

		abstract = Mandar::Core::Config.abstract
		aws_account_elem = abstract["aws-account"].find_first("*[@name='#{aws_account_name}']") \
			or raise "aws account not found: #{aws_account_name}"

		ret = Mandar::AWS::Account.new

		ret.name = aws_account_name
		ret.access_key_id = aws_account_elem.attributes["access-key-id"]
		ret.secret_access_key = aws_account_elem.attributes["secret-access-key"]
		ret.user_id = aws_account_elem.attributes["user-id"]

		ret.freeze

		return ret
	end

end

require "mandar/ec2/actions.rb"
require "mandar/ec2/ec2loadbalancer.rb"
require "mandar/ec2/securitygroups.rb"
require "mandar/ec2/reports.rb"
require "mandar/ec2/utils.rb"
