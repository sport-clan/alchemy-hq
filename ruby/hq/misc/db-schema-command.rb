module HQ
module Misc

class DbSchemaCommand

	attr_accessor :hq

	def couch() hq.couch end
	def logger() hq.logger end

	def go command_name

		couch.create({
			"_id" => "_design/root",
			"language" => "javascript",
			"views" => {
				"by_type" => {
					"map" =>
						"function (doc) {\n" \
						"    if (! doc.transaction) return;\n" \
						"    emit (doc.type, doc);\n" \
						"}\n",
				}
			},
		})

	end

end

end
end
