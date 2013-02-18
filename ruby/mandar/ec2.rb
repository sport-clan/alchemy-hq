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

end

require "mandar/ec2/ec2loadbalancer.rb"
require "mandar/ec2/securitygroups.rb"
require "mandar/ec2/reports.rb"
require "mandar/ec2/utils.rb"
