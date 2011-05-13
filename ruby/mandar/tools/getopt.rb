module Mandar::Tools::Getopt

	def self.process argv, easy_specs

		# convert easy_specs into specs
		specs = {}
		easy_specs.each do |easy_spec|
			spec = {}
			spec[:long_name] = "--#{easy_spec[:name].to_s.gsub "_", "-"}"
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
		end

		# save main argv value because we clobber it
		old_argv = []
		ARGV.each { |arg| old_argv << arg }
		new_argv = []
		argv.each { |arg| new_argv << arg }
		begin

			require "getoptlong"
			getopt_args = []
			ret = {}
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
				ret[spec[:key]] = spec[:arg_value] if [ :optional, :switch_default ].include? spec[:type]
				ret[spec[:key]] = [] if spec[:multi]
				ret[spec[:key]] = false if spec[:type] == :boolean
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
				$stderr.puts "#{$0}: option '#{spec[:long_name]}' is required"
				raise Mandar::Tools::GetoptError
			end

			# check for mismatched arguments
			specs.values.each do |spec|
				next unless ret.include? spec[:key]
				next unless spec[:verify].is_a? Regexp
				next if ret[spec[:key]] == spec[:arg_value]
				if spec[:multi]
					ret[spec[:key]].each do |value|
						next if value =~ /^#{spec[:verify]}$/
						$stderr.puts "#{$0}: option '#{spec[:long_name]}' is invalid: #{value}"
						raise Mandar::Tools::GetoptError
					end
				else
					next if ret[spec[:key]] =~ /^#{spec[:verify]}$/
					$stderr.puts "#{$0}: option '#{spec[:long_name]}' is invalid: #{ret[spec[:key]]}"
					raise Mandar::Tools::GetoptError
				end
			end

			# perform conversions
			specs.values.each do |spec|
				next unless ret.include? spec[:key]
				next unless spec[:convert].is_a? Symbol
				ret[spec[:key]] = ret[spec[:key]].send spec[:convert]
			end

			rest = []
			ARGV.each { |arg| rest << arg }
			return ret, rest

		rescue GetoptLong::MissingArgument
			raise Mandar::Tools::GetoptError

		ensure
			ARGV.clear
			old_argv.each { |arg| ARGV << arg }
		end
	end

end

class Mandar::Tools::GetoptError < StandardError
end
