module Mandar::Support::Ruby

	Mandar::Deploy::Commands.register self, :gem
	Mandar::Deploy::Commands.register self, :gem_source

	def self.command_gem_source(gem_source_elem)

		gem_source_ruby = gem_source_elem.attributes["ruby"]
		gem_source_url = gem_source_elem.attributes["url"]

		@gem_sources ||= {}

		unless @gem_sources[gem_source_ruby]
			Mandar.time "gem#{gem_source_ruby} sources --list" do
				@gem_sources[gem_source_ruby] =
					%x[ gem#{gem_source_ruby} sources --list ].split("\n")[2..-1] || []
			end
		end

		unless @gem_sources[gem_source_ruby].include? gem_source_url
			Mandar.notice "adding gem source #{gem_source_url} for ruby #{gem_source_ruby}"
			system "nice gem#{gem_source_ruby} sources --quiet --add #{gem_source_url}" or raise "Error" unless $mock
			@gem_sources[gem_source_ruby] << gem_source_url
		end
	end

	def self.command_gem(gem_elem)

		Mandar::Debian.apt_install "ruby-dev"

		gem_ruby = gem_elem.attributes["ruby"]
		gem_name = gem_elem.attributes["name"]
		gem_version = gem_elem.attributes["version"]

		@gem_packages ||= {}

		unless @gem_packages[gem_ruby]
			Mandar.time "gem#{gem_ruby} list" do
				@gem_packages[gem_ruby] = {}
				%x[ gem#{gem_ruby} list ].split("\n").each do |line|
					line =~ /^(\S+) \(([0-9]+(?:\.[0-9]+)*(?:, [0-9]+(?:\.[0-9]+)*)*)\)/ \
						or raise "didn't understand output of gem list: #{line}"
					name, vers = $1, $2
					@gem_packages[gem_ruby][name] = {}
					vers.split(/, /).each do |ver|
						@gem_packages[gem_ruby][name][ver] = true
					end
				end
			end
		end

		unless @gem_packages[gem_ruby][gem_name] \
				&& @gem_packages[gem_ruby][gem_name][gem_version]

			Mandar.notice "installing gem #{gem_name}-#{gem_version} for " +
				"ruby #{gem_ruby}"

			unless $mosk
				system "gem#{gem_ruby} install #{gem_name} --version " +
						"#{gem_version}" \
					or raise "Error"
			end

			@gem_packages[gem_ruby][gem_name] ||= {}

			@gem_packages[gem_ruby][gem_name][gem_version] = true
		end
	end

end
