#!/usr/bin/env ruby

module HQ::Tools::Lock

	def self.lock_simple filename

		# create a lock file

		mode = File::WRONLY | File::CREAT | File::EXCL
		File.open filename, mode do |file|

			# flock it

			file.flock File::LOCK_EX | File::LOCK_NB \
				or raise "Cannot obtain lock"

			# write our pid

			file.puts $$
			file.flush

			# yield

			yield

			# delete lock file

			File.unlink filename

		end

	end

	def self.lock_remove filename

		# file already exists, try locking that

		File.open filename, File::WRONLY do |file|

			# lock it

			file.flock File::LOCK_EX | File::LOCK_NB \
				or raise "Cannot obtain lock"

			# delete lock file

			File.unlink filename

		end

	end

	def self.lock filename, &proc

		while true

			begin

				lock_simple filename, &proc
				return

			rescue Errno::EEXIST => e

				lock_remove filename

			end

		end

	end

end
