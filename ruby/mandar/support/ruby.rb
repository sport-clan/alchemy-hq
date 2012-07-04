module Mandar::Support::Ruby

	Mandar::Deploy::Commands.register self, :gem
	Mandar::Deploy::Commands.register self, :gem_source

	RVM_MAGIC =
		"test -f /etc/profile.d/rvm.sh && { " +
			". /etc/profile.d/rvm.sh; " +
			"rvm use system; " +
		"};"

	def self.command_gem_source gem_source_elem

		gem_source_ruby = gem_source_elem.attributes["ruby"]
		gem_source_url = gem_source_elem.attributes["url"]

		@gem_sources ||= {}

		unless @gem_sources[gem_source_ruby]
			Mandar.time "gem#{gem_source_ruby} sources --list" do

				command =
					"#{RVM_MAGIC} gem#{gem_source_ruby} sources --list"

				result =
					Mandar::Support::Core.shell_real command

				result[:status] == 0 \
					or raise "Error"

				@gem_sources[gem_source_ruby] =
					result[:output].select do |line|
						case line
							when /^Now using system ruby\.$/
								false
							when /^\*\*\* CURRENT SOURCES \*\*\*$/
								false
							when /^$/
								false
							when /^http:\/\/[^\/]+\/$/
								true
							else
								raise "Error: #{line}"
						end
					end

			end
		end

		unless @gem_sources[gem_source_ruby].include? gem_source_url

			message = "adding gem source #{gem_source_url} for ruby " +
				"#{gem_source_ruby}"

			Mandar.notice "adding gem source #{gem_source_url} for ruby " +
				"#{gem_source_ruby}"

			unless $mock
				Mandar.time message do

					command =
						Mandar.shell_quote [
							"gem#{gem_source_ruby}",
							"sources",
							"--quiet",
							"--add", gem_source_url,
						]

					result =
						Mandar::Support::Core.shell_real \
							"#{RVM_MAGIC} nice #{command}"

					result[:status] == 0 \
						or raise "Error"

				end
			end

			@gem_sources[gem_source_ruby] << gem_source_url

		end
	end

	def self.command_gem gem_elem

		Mandar::Debian.apt_install "ruby-dev"

		gem_ruby = gem_elem.attributes["ruby"]
		gem_name = gem_elem.attributes["name"]
		gem_version = gem_elem.attributes["version"]

		# cache list of installed gems for each ruby

		@gem_packages ||= {}

		unless @gem_packages[gem_ruby]

			Mandar.time "gem#{gem_ruby} list" do

				@gem_packages[gem_ruby] = {}

				command =
					Mandar.shell_quote [
						"gem#{gem_ruby}",
						"list",
					]

				result =
					Mandar::Support::Core.shell_real \
						"#{RVM_MAGIC} nice #{command}"

				result[:status] == 0 \
					or raise "Error"

				result[:output].each do |line|

					next if line =~ /^Now using system ruby\.$/

					line =~ /^
						(\S+) \s \( (
							[0-9]+ (?: \. [0-9]+ )*
							(?: , \s
								[0-9]+ (?: \. [0-9]+ )*
							)*
						) \)
					/x \
						or raise "didn't understand output of gem list: #{line}"

					name, vers = $1, $2

					@gem_packages[gem_ruby][name] = {}

					vers.split(/, /).each do |ver|
						@gem_packages[gem_ruby][name][ver] = true
					end

				end
			end
		end

		# install package if not already installed

		unless @gem_packages[gem_ruby][gem_name] \
				&& @gem_packages[gem_ruby][gem_name][gem_version]

			message = "installing gem #{gem_name}-#{gem_version} for " +
				"ruby #{gem_ruby}"

			Mandar.notice message

			unless $mock
				Mandar.time message do

					command =
						Mandar.shell_quote [
							"gem#{gem_ruby}",
							"install",
							gem_name,
							"--version",
							gem_version,
						]

					result =
						Mandar::Support::Core.shell_real \
							"#{RVM_MAGIC} nice #{command}"

					result[:status] == 0 \
						or raise "Error"

				end
			end

			@gem_packages[gem_ruby][gem_name] ||= {}

			@gem_packages[gem_ruby][gem_name][gem_version] = true

		end

	end

end
