# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/url"

describe Protocol::URL::Relative do
	it "creates a relative URL" do
		url = Protocol::URL::Relative.new("/_components/")
		expect(url.path).to be == "/_components/"
	end
	
	it "concatenates with another relative path" do
		base = Protocol::URL::Relative.new("/_components/")
		other = Protocol::URL::Relative.new("button.js")
		result = base + other
		expect(result).to be_a(Protocol::URL::Relative)
		expect(result.to_s).to be == "/_components/button.js"
	end
	
	it "simplifies .. in base path" do
		base = Protocol::URL["bar/.."]
		relative = Protocol::URL["baz/file.txt"]
		result = base + relative
		expect(result.to_s).to be == "baz/file.txt"
	end
	
	with "#+" do
		it "returns Absolute when adding Absolute to Relative" do
			relative = Protocol::URL::Relative.new("/path")
			absolute = Protocol::URL::Absolute.new("https", "//example.com", "/other")
			result = relative + absolute
			expect(result).to be_equal(absolute)
		end
		
		it "handles String argument" do
			relative = Protocol::URL::Relative.new("/base/")
			result = relative + "path.html"
			expect(result.path).to be == "/base/path.html"
		end
		
		it "raises error for invalid type" do
			relative = Protocol::URL::Relative.new("/path")
			expect do
				relative + 123
			end.to raise_exception(ArgumentError, message: be =~ /Cannot combine/)
		end
	end
end
