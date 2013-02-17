module Mandar::Support::RRD

	def self.rrd
		require "RRD"
		return RRD
	end

	def self.drill_down(getter, setter, key)
		case key

		when ""
			return getter, setter

		when /^\[(\d+)\](.*)$/
			setter.call([]) if getter.call.nil?
			raise "error" unless getter.call.is_a? Array
			array = getter.call
			return drill_down(
				lambda { array[$1.to_i] },
				lambda { |val| array[$1.to_i] = val },
				$2)

		when /^\[([-a-z_]+)\](.*)$/
			setter.call({}) if getter.call.nil?
			raise "error" unless getter.call.is_a? Hash
			hash = getter.call
			return drill_down(
				getter = lambda { hash[$1] },
				setter = lambda { |val| hash[$1] = val },
				$2)

		when /^\.([-a-z_]+)(.*)$/
			setter.call({}) if getter.call.nil?
			raise "error" unless getter.call.is_a? Hash
			hash = getter.call
			return drill_down(
				getter = lambda { hash[$1.to_sym] },
				setter = lambda { |val| hash[$1.to_sym] = val },
				$2)

		else
			raise "don't know how to continue at: #{key}"

		end
	end

	def self.rrd_info path

		rrdtool_info_args = [
			"rrdtool",
			"info",
			path,
		]

		rrdtool_info_cmd =
			Mandar.shell_quote rrdtool_info_args

		rrdtool_info_result =
			Mandar::Support::Core.shell_real \
				rrdtool_info_cmd

		return \
			Hash[
				rrdtool_info_result[:output].map do
					|line|

					case line

						when /^(\S+) = (\d+)$/
							[ $1, $2.to_i ]

						when /^(\S+) = NaN$/
							[ $1, nil ]

						when /^(\S+) = "([^"]+)"$/
							[ $1, $2 ]

						when /^(\S+) = (\d,\d+e[-+]\d+)$/
							[ $1, $2.gsub(",",".").to_f ]

						else
							raise "Error: #{line}"

					end

				end
			]

	end

	def self.load_spec path

		info_raw =
			rrd_info path

		info = {}
		info_raw.each do |key, val|
			getter, setter = drill_down lambda { info }, nil, ".#{key}"
			setter.call val
		end

		info_spec = {
			:step => info[:step],
			:data_sources => info[:ds].map { |name, ds|
				{
					:index => ds[:index],
					:name => name,
					:type => ds[:type].downcase,
					:heartbeat => ds[:minimal_heartbeat],
				}
			}.sort { |a, b|
				a[:index] <=> b[:index]
			}.each { |data_source|
				data_source.delete :index
			},
			:archives => info[:rra].map { |rra|
				{
					:function => rra[:cf].downcase,
					:factor => rra[:xff],
					:steps => rra[:pdp_per_row],
					:rows => rra[:rows],
				}
			},
		}

		return info_spec
	end

	def self.rrd_database(path, spec, options)

		if File.exists? path

			existing_spec = load_spec(path)

			return if spec == existing_spec

			raise "TODO"

		else

			Mandar.notice "creating #{path}"

			args = %W[
				#{path}.tmp
				--step #{spec[:step]}
				--no-overwrite
			] + spec[:data_sources].map { |data_source|
				[
					"DS",
					data_source[:name],
					data_source[:type].upcase,
					data_source[:heartbeat],
					"U",
					"U",
				].join(":")
			} + spec[:archives].map { |archive|
				[
					"RRA",
					archive[:function].upcase,
					archive[:factor],
					archive[:steps],
					archive[:rows],
				].join(":")
			}

			unless $mock
				rrd.create *args
				FileUtils.chown options[:user], options[:group], "#{path}.tmp"
				FileUtils.chmod options[:mode], "#{path}.tmp"
				FileUtils.mv "#{path}.tmp", path
			end

		end
	end

	def self.graph(graph_spec)
		Tempfile.open "mandar-rrd-" do |tmp|

			args = %W[
				#{tmp.path}
				--start #{graph_spec[:start]}
				--end #{graph_spec[:end]}
				--width #{graph_spec[:width]}
				--height #{graph_spec[:height]}
				--slope-mode
				--rigid
			] + graph_spec[:data].map { |data|
				%W[
					DEF
					#{data[:name]}=#{data[:source_file]}
					#{data[:source_name]}
					#{data[:source_function].upcase}
				].join(":")
			} + graph_spec[:calc].map { |calc|
				"CDEF:#{calc[:name]}=#{calc[:rpn]}"
			} + graph_spec[:outputs].map { |output|
				(
					%W[
						#{output[:type].upcase}
						#{output[:data]}\##{output[:colour]}
						#{output[:label]}
					] + (output[:stack] ? [ "STACK" ] : [])
				).join(":")
			}

			rrd.graph *args

			return File.read(tmp.path)
		end
	end

	def self.update(name, spec)
		args = %W[
			#{name}.rrd
			--daemon #{spec[:daemon]}
			N:#{spec[:data].join(":")}
		]
		rrd.update(*args)
	end

	Mandar::Deploy::Commands.register self, :rrd_database

	def self.command_rrd_database(db_elem)

		db_name = db_elem.attributes["name"]

		spec = {
			:step => db_elem.attributes["step"].to_i,
			:data_sources => db_elem.find("data-source").map { |data_source_elem|
				{
					:name => data_source_elem.attributes["name"],
					:type => data_source_elem.attributes["type"],
					:heartbeat => data_source_elem.attributes["heartbeat"].to_i,
				}
			},
			:archives => db_elem.find("archive").map { |archive_elem|
				{
					:function => archive_elem.attributes["function"],
					:factor => archive_elem.attributes["factor"].to_f,
					:steps => archive_elem.attributes["steps"].to_i,
					:rows => archive_elem.attributes["rows"].to_i,
				}
			},
		}

		rrd_database db_name, spec, {
			:user => db_elem.attributes["user"],
			:group => db_elem.attributes["group"],
			:mode => db_elem.attributes["mode"].to_i(8),
		}
	end

end
