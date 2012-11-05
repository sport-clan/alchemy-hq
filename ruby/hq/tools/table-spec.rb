require "hq/tools/table"

describe HQ::Tools::Table do

	subject do
		HQ::Tools::Table.new
	end

	describe "#initialize" do

		it "sets rows to []" do
			subject.rows.should == []
		end

		it "sets cats to {}" do
			subject.cats.should == {}
		end

	end

	describe "#push" do

		context "when there are no existing rows" do

			it "adds the row" do
				subject.push [ "first", "second" ], "cat"
				subject.rows.size.should == 1
				subject.rows[0][:cat].should == "cat"
				subject.rows[0][:cols].size.should == 2
				subject.rows[0][:cols][0].should == "first"
				subject.rows[0][:cols][1].should == "second"
			end

			it "adds the category" do
				subject.push [ "first", "second" ], "cat"
				subject.cats.size.should == 1
				subject.cats.should have_key "cat"
			end

		end

	end

	describe "#print" do
	end

end
