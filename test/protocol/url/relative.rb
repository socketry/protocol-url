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
	
	it "preserves .. in base path" do
		base = Protocol::URL["bar/.."]
		relative = Protocol::URL["baz/file.txt"]
		result = base + relative
		expect(result.to_s).to be == "bar/../baz/file.txt"
	end
end
