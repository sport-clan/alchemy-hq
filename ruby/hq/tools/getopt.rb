#!/usr/bin/env ruby

require "hq/tools"

module HQ::Tools::Getopt

	def self.to_long name
		return "--#{name.to_s.gsub "_", "-"}"
	end

	def self.process argv, easy_specs

		# convert easy_specs into specs
		specs = {}
		ret = {}
		easy_specs.each do |easy_spec|
			if easy_spec[:options]
				options = easy_spec[:options].clone
				options << easy_spec[:default] if easy_spec[:default]
				options.each do |option|
					spec = {}
					spec[:long_name] = to_long option
					spec[:type] = option == easy_spec[:default] ? :switch_default : :switch
					spec[:key] = easy_spec[:name]
					spec[:arg_value] = option
					specs[spec[:long_name]] = spec
				end
				ret[easy_spec[:name]] = easy_spec[:default]
			else
				easy_spec[:long_name] = to_long easy_spec[:name]
				spec = {}
				spec[:long_name] = to_long easy_spec[:name]
				spec[:type] = case
					when easy_spec[:boolean] then :boolean
					when easy_spec[:required] then :required
					else :optional
				end
				spec[:key] = easy_spec[:name]
				spec[:arg_value] = easy_spec[:default]
				spec[:verify] = easy_spec[:regex]
				spec[:convert] = easy_spec[:convert]
				spec[:multi] = easy_spec[:multi]
				specs[spec[:long_name]] = spec
				if easy_spec[:multi]
					ret[easy_spec[:name]] = []
				elsif easy_spec[:boolean]
					ret[easy_spec[:name]] = false
				elsif easy_spec[:required]
					# do nothing
				else
					ret[easy_spec[:name]] = easy_spec[:default]
				end
			end
		end

		# save main argv value because we clobber it
		old_argv = []
		ARGV.each { |arg| old_argv << arg }
		new_argv = []
		argv.each { |arg| new_argv << arg }
		begin

			require "getoptlong"
			getopt_args = []
			specs.each do |long_name, spec|
				getopt_flags = case spec[:type]
					when :required then GetoptLong::REQUIRED_ARGUMENT
					when :optional then GetoptLong::REQUIRED_ARGUMENT
					when :boolean then GetoptLong::NO_ARGUMENT
					when :switch then GetoptLong::NO_ARGUMENT
					when :switch_default then GetoptLong::NO_ARGUMENT
					else raise "Invalid getopt argument type: #{spec[:type]}"
				end
				getopt_args << [ spec[:long_name], getopt_flags ]
				#ret[spec[:key]] = spec[:arg_value] if [ :optional, :switch_default ].include? spec[:type]
				#ret[spec[:key]] = [] if spec[:multi]
				#ret[spec[:key]] = false if spec[:type] == :boolean
			end
			ARGV.clear
			new_argv.each { |arg| ARGV << arg }
			GetoptLong.new(*getopt_args).each do |opt, arg|
				spec = specs[opt]
				case spec[:type]
					when :required, :optional
						ret[spec[:key]] << arg if spec[:multi]
						ret[spec[:key]] = arg unless spec[:multi]
					when :switch, :switch_default
						ret[spec[:key]] = spec[:arg_value]
					when :boolean
						ret[spec[:key]] = true
					else
						raise "Error"
				end
			end

			# check for missing required arguments
			specs.values.each do |spec|
				next unless spec[:type] == :required
				next if ! spec[:multi] && ret.include?(spec[:key])
				next if spec[:multi] && ! ret[spec[:key]].empty?
				msg = "#{$0}: option '#{spec[:long_name]}' is required"
				$stderr.puts msg
				raise HQ::Tools::GetoptError.new msg
			end

			# check for mismatched regex arguments
			easy_specs.each do |easy_spec|
				next unless easy_spec[:regex]
				if easy_spec[:multi]
					ret[easy_spec[:name]].each do |value|
						next if value =~ /^#{easy_spec[:regex]}$/
						msg = "#{$0}: option '#{easy_spec[:long_name]}' is invalid: #{value}"
						$stderr.puts msg
						raise HQ::Tools::GetoptError.new msg
					end
				else
					next if ret[easy_spec[:name]] == easy_spec[:default]
					next if ret[easy_spec[:name]] =~ /^#{easy_spec[:regex]}$/
					msg = "#{$0}: option '#{easy_spec[:long_name]}' is invalid: #{ret[easy_spec[:name]]}"
					$stderr.puts msg
					raise HQ::Tools::GetoptError.new msg
				end
			end

			# perform conversions
			specs.values.each do |spec|
				next unless ret[spec[:key]].is_a? String
				case spec[:convert]
				when nil
					# do nothing
				when Symbol
					ret[spec[:key]] = ret[spec[:key]].send spec[:convert]
				when Method
					ret[spec[:key]] = spec[:convert].call ret[spec[:key]]
				else
					raise "Don't know what to do with #{spec[:convert].class}"
				end
			end

			rest = []
			ARGV.each { |arg| rest << arg }
			return ret, rest

		rescue GetoptLong::MissingArgument
			raise HQ::Tools::GetoptError

		ensure
			ARGV.clear
			old_argv.each { |arg| ARGV << arg }
		end
	end

end

class HQ::Tools::GetoptError < StandardError
end
