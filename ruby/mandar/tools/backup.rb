module Mandar::Tools::Backup

	PERIODS = {
		:year => lambda { |t| t.strftime "%Y" },
		:month => lambda { |t| t.strftime "%Y-%m" },
		:week => lambda { |t| t.strftime "%YW%U" },
		:day => lambda { |t| t.strftime "%Y-%m-%d" },
		:hour => lambda { |t| t.strftime "%Y-%m-%dT%H" },
		:second => lambda { |t| t.strftime "%Y-%m-%dT%H:%M:%S" },
	}

	RULES = {
		:high => {
			:year => 9999,
			:month => 24,
			:week => 13,
			:day => 14,
			:hour => 48,
			:second => 1,
		},
		:low => {
			:year => 9999,
			:month => 6,
			:week => 3,
			:day => 4,
			:hour => 12,
			:second => 1,
		},
		:minimal => {
			:year => 9999,
			:month => 1,
			:week => 1,
			:day => 1,
			:hour => 1,
			:second => 1,
		},
	}

	def self.choose_keepers(items, rule)

		# collect items grouped by period
		items_by_period = {}
		all_item_ids = Set.new
		items.each do |item|
			PERIODS.each do |name, func|
				items_by_period[name] ||= {}
				tp = func.call item[:timestamp]
				if not items_by_period[name][tp] or item[:timestamp] < items_by_period[name][tp][:timestamp]
					items_by_period[name][tp] = item
				end
			end
			all_item_ids.add item[:id]
		end

		# work out which items to keep from each period
		keepers = {}
		PERIODS.each do |name, func|
			list = items_by_period[name].values
			list.sort! { |a, b| a[:timestamp] <=> b[:timestamp] }
			target = rule[name]
			list = list[-target..-1] if list.size > target
			list.each do |item|
				keepers[item[:id]] ||= []
				keepers[item[:id]].push name
			end
		end

		return keepers
	end

end
