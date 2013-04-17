require "rspec/core/rake_task"
require "cucumber/rake/task"

HQ_DIR = File.dirname __FILE__ \
	unless defined? HQ_DIR

desc "Default: run tests"
task :default => [ :spec, :features ]

desc "Run specs"
RSpec::Core::RakeTask.new :spec do
	|task|

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

desc "Run features"
Cucumber::Rake::Task.new :features do
	|task|

	task.cucumber_opts = [
		"features",

		"--format progress",

		"--format junit",
		"--out results/cucumber",

		"--format html",
		"--out results/cucumber.html",

	].join " "

end
