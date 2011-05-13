module Mandar::Console::Data

	def data_clone data
		return case data
			when NilClass then nil
			when String then data.clone
			when Integer then data
			when TrueClass, FalseClass then data
			when Array then data.map { |x| data_clone x }
			when Hash then Hash[*data.map { |k, v| [ k, data_clone(v) ] }.flatten(1)]
			else raise "Can't clone #{data.class}"
		end
	end

	def data_string data
		return case data
			when NilClass then "nil"
			when String then "\"#{data}\""
			when Integer then data.to_s
			when TrueClass, FalseClass then data ? "true" : "false"
			when Array then "[ " + data.map { |x| data_string x }.join(", ") + " ]"
			when Hash then "{ " + data.map { |k, v| "#{k}: #{data_string v}" }.join(", ") + " }"
			else raise "Can't convert #{data.class} to string"
		end
	end

end
