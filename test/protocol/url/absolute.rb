# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/url"

describe Protocol::URL::Absolute do
	it "creates an absolute URL" do
		url = Protocol::URL::Absolute.new("https", "cdn.example.com", "/npm/")
		expect(url.scheme).to be == "https"
		expect(url.authority).to be == "cdn.example.com"
		expect(url.path).to be == "/npm/"
		expect(url.to_s).to be == "https://cdn.example.com/npm/"
	end
	
	it "concatenates with a relative path" do
		base = Protocol::URL::Absolute.new("https", "cdn.example.com", "/npm/")
		relative = Protocol::URL::Relative.new("lit@2.7.5/index.js")
		result = base + relative
		expect(result).to be_a(Protocol::URL::Absolute)
		expect(result.to_s).to be == "https://cdn.example.com/npm/lit@2.7.5/index.js"
	end
	
	describe "fragment encoding" do
		it "decodes percent-encoded fragments on parse" do
			url = Protocol::URL["http://example.com/path#hello%20world"]
			expect(url.fragment).to be == "hello world"
			expect(url.to_s).to be == "http://example.com/path#hello%20world"
		end
		
		it "preserves encoded fragments" do
			url = Protocol::URL["http://example.com/path#hello%3C%3E"]
			expect(url.fragment).to be == "hello<>"
			expect(url.to_s).to be == "http://example.com/path#hello%3C%3E"
		end
		
		it "does not encode allowed fragment characters" do
			url = Protocol::URL["http://example.com/path#section/1.2?query"]
			# / and ? are allowed in fragments per RFC 3986
			expect(url.fragment).to be == "section/1.2?query"
			expect(url.to_s).to be == "http://example.com/path#section/1.2?query"
		end
	end
	
	with "#+" do
		it "returns other when adding Absolute with scheme" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/path")
			other = Protocol::URL::Absolute.new("http", "other.com", "/other")
			result = base + other
			expect(result).to be_equal(other)
		end
		
		it "handles protocol-relative Absolute URL" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/path")
			other = Protocol::URL::Absolute.new(nil, "cdn.example.com", "/lib.js")
			result = base + other
			expect(result.scheme).to be == "https"
			expect(result.authority).to be == "cdn.example.com"
			expect(result.path).to be == "/lib.js"
		end
		
		it "handles Reference argument" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/path")
			reference = Protocol::URL::Reference.new("other.html", nil, nil, nil)
			result = base + reference
			expect(result.path).to be == "/other.html"
		end
		
		it "raises error for invalid type" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/path")
			expect do
				base + 123
			end.to raise_exception(ArgumentError, message: be =~ /Cannot combine/)
		end
	end
end
