require "rspec/core/rake_task"

HQ_DIR = File.dirname __FILE__

desc "Default: run tests"
task :default => [ :spec ]

desc "Run specs"
RSpec::Core::RakeTask.new(:spec) do |task|

	task.pattern = "ruby/**/*-spec.rb"

	task.rspec_opts = [

		"--format progress",

		"--format html",
		"--out results/rspec.html",

		"--format RspecJunitFormatter",
		"--out results/rspec.xml",

	].join " "

	task.ruby_opts = [
		"-I #{HQ_DIR}/ruby",
		"-r #{HQ_DIR}/etc/simplecov.rb",
	].join " "

end
