require "mandar"

class Mandar::Tools::Table

	def initialize()
		@rows = []
		@cats = {}
	end

	def push(cols, cat = "default")
		@rows.push({
			:cat => cat,
			:cols => cols,
		})
		@cats[cat] = [] unless @cats[cat]
		cols.each_with_index do |col, i|
			@cats[cat][i] = 0 unless @cats[cat][i]
			@cats[cat][i] = col.to_s.length if @cats[cat][i] < col.to_s.length
		end
	end

	def print(f = $stdout)
		for row in @rows
			cat = row[:cat]
			cols = row[:cols]
			line = ""
			cols.each_with_index do |col, i|
				line += " " unless i == 0
				line += col.to_s.ljust @cats[cat][i]
			end
			f.print "#{line.rstrip}\n"
		end
	end
end
