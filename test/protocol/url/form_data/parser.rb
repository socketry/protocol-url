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
	
	it "parses form data into a supplied result" do
		result = Struct.new(:pairs) do
			def add(name, value)
				pairs << [name, value]
			end
			
			def to_h
				return pairs.to_h
			end
		end.new([])
		
		parameters = parser.parse(StringIO.new("name=Samuel"), result)
		
		expect(parameters).to be == {"name" => "Samuel"}
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
	
	it "applies the encoded size limit at its boundary" do
		parser = subject.new(size_limit: 4)
		
		expect(parser.parse(StringIO.new("a=1"))).to be == {"a" => "1"}
		expect(parser.parse(StringIO.new("a=12"))).to be == {"a" => "12"}
		
		expect do
			parser.parse(StringIO.new("a=123"))
		end.to raise_exception(RangeError, message: be =~ /size exceeded limit of 4/)
	end
	
	it "applies the pair count limit at its boundary" do
		parser = subject.new(pair_count_limit: 2)
		
		expect(parser.parse(StringIO.new("a=1"))).to be == {"a" => "1"}
		expect(parser.parse(StringIO.new("a=1&b=2"))).to be == {"a" => "1", "b" => "2"}
		
		expect do
			parser.parse(StringIO.new("a=1&b=2&c=3"))
		end.to raise_exception(RangeError, message: be =~ /pair_count exceeded limit of 2/)
	end
	
	it "allows limits to be disabled" do
		parser = subject.new(size_limit: nil, pair_count_limit: nil)
		
		expect(parser.each(StringIO.new("a=1&b=2")).to_a).to be == [["a", "1"], ["b", "2"]]
	end
	
	it "applies the nesting depth limit at its boundary" do
		parser = subject.new(depth_limit: 2)
		
		expect(parser.parse(StringIO.new("a=1"))).to be == {"a" => "1"}
		expect(parser.parse(StringIO.new("a%5Bb%5D=1"))).to be == {"a" => {"b" => "1"}}
		
		expect do
			parser.parse(StringIO.new("a%5Bb%5D%5Bc%5D=1"))
		end.to raise_exception(RangeError, message: be =~ /depth exceeded limit of 2/)
	end
	
	it "rejects an empty name when building nested form data" do
		expect do
			parser.parse(StringIO.new("=value"))
		end.to raise_exception(ArgumentError, message: be =~ /Invalid form data name/)
	end
end
