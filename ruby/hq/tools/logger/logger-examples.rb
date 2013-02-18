shared_examples_for "a logger" do

	let(:string_io) { StringIO.new }

	before do
		subject.out = string_io
		subject.level = :debug
	end

	def output_for content

		subject.output \
			content,
			{ prefix: "|", mode: "normal" }

		return string_io.string

	end

	let :sample_exception do
		{
			"type" => "exception",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"message" => "message",
			"backtrace" => [
				"backtrace 1",
				"backtrace 2",
			],
		}
	end

	let :sample_log_without_content do
		{
			"type" => "log",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
		}
	end

	let :sample_log_with_empty_content do
		{
			"type" => "log",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"content" => [],
		}
	end

	let :sample_log_with_content do
		{
			"type" => "log",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"content" => [
				"content 1",
				"content 2",
			],
		}
	end

	let :sample_exception do
		{
			"type" => "exception",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"message" => "message",
			"backtrace" => [
				"backtrace 1",
				"backtrace 2",
			],
		}
	end

	let :sample_diff do
		{
			"type" => "diff",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"content" => [
				{ "type" => "diff-minus-minus-minus", "text" => "diff 1" },
				{ "type" => "diff-plus-plus-plus", "text" => "diff 2" },
				{ "type" => "diff-at-at", "text" => "diff 3" },
				{ "type" => "diff-minus", "text" => "diff 4" },
				{ "type" => "diff-plus", "text" => "diff 5" },
				{ "type" => "diff-else", "text" => "diff 6" },
			],
		}
	end

	let :sample_command_without_output do
		{
			"type" => "command",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
		}
	end

	let :sample_command_with_output do
		{
			"type" => "command",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
			"output" => [
				"output 1",
				"output 2",
			],
		}
	end

	let :sample_command_output do
		{
			"type" => "command-output",
			"level" => "debug",
			"hostname" => "hostname",
			"text" => "text",
		}
	end

end
