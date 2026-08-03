# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/url/form_data/parser"
require "stringio"

describe Protocol::URL::FormData::Parser do
	let(:parser) {subject.new}
	
	it "parses form pairs incrementally" do
		body = Struct.new(:chunks) do
			def read
				chunks.shift
			end
		end.new(["name=Samuel+", "Williams&operator=%", "2B&empty=&bare"])
		
		pairs = []
		parser.each(body) do |name, value|
			pairs << [name, value]
		end
		
		expect(pairs).to be == [
			["name", "Samuel Williams"],
			["operator", "+"],
			["empty", ""],
			["bare", nil],
		]
	end
	
	it "preserves duplicate and empty names" do
		pairs = parser.each(StringIO.new("tag=one&tag=two&=value")).to_a
		
		expect(pairs).to be == [["tag", "one"], ["tag", "two"], ["", "value"]]
	end
	
	it "parses nested form data" do
		parameters = parser.parse(StringIO.new("user[name]=Samuel&user[roles][]=admin&user[roles][]=editor"))
		
		expect(parameters).to be == {
			"user" => {"name" => "Samuel", "roles" => ["admin", "editor"]},
		}
	end
	
	it "distinguishes absent and empty values" do
		parameters = parser.parse(StringIO.new("absent&empty="))
		
		expect(parameters).to be == {"absent" => nil, "empty" => ""}
	end
	
	it "allows values to be transformed while parsing" do
		parameters = parser.parse(StringIO.new("count=12")) do |_name, value|
			Integer(value)
		end
		
		expect(parameters).to be == {"count" => 12}
	end
	
	it "limits the total encoded size" do
		parser = subject.new(maximum_total_size: 4)
		
		expect do
			parser.each(StringIO.new("name=Samuel")).to_a
		end.to raise_exception(RangeError, message: be =~ /total_size exceeded/)
	end
	
	it "limits the number of pairs" do
		parser = subject.new(maximum_pair_count: 1)
		
		expect do
			parser.each(StringIO.new("a=1&b=2")).to_a
		end.to raise_exception(RangeError, message: be =~ /pair_count exceeded/)
	end
	
	it "allows limits to be disabled" do
		parser = subject.new(maximum_total_size: nil, maximum_pair_count: nil)
		
		expect(parser.each(StringIO.new("a=1&b=2")).to_a).to be == [["a", "1"], ["b", "2"]]
	end
	
	it "limits nested form names" do
		parser = subject.new(maximum_depth: 2)
		
		expect do
			parser.parse(StringIO.new("a[b][c]=value"))
		end.to raise_exception(RangeError, message: be =~ /depth exceeded/)
	end
	
	it "rejects an empty name when building nested form data" do
		expect do
			parser.parse(StringIO.new("=value"))
		end.to raise_exception(ArgumentError, message: be =~ /Invalid form data name/)
	end
end
