# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/url"

describe Protocol::URL do
	describe ".[]" do
		it "coerces absolute URLs with scheme" do
			url = Protocol::URL["https://cdn.example.com/npm/"]
			expect(url).to be_a(Protocol::URL::Absolute)
			expect(url.scheme).to be == "https"
			expect(url.authority).to be == "cdn.example.com"
			expect(url.path).to be == "/npm/"
		end
		
		it "coerces protocol-relative URLs" do
			url = Protocol::URL["//cdn.example.com/npm/"]
			expect(url).to be_a(Protocol::URL::Absolute)
			expect(url.scheme).to be == nil
			expect(url.authority).to be == "cdn.example.com"
			expect(url.path).to be == "/npm/"
		end
		
		it "coerces relative paths" do
			url = Protocol::URL["/_components/"]
			expect(url).to be_a(Protocol::URL::Relative)
			expect(url.path).to be == "/_components/"
		end
		
		it "returns nil for nil input" do
			url = Protocol::URL[nil]
			expect(url).to be_nil
		end
		
		it "returns same object if already a Relative" do
			relative = Protocol::URL::Relative.new("/path")
			url = Protocol::URL[relative]
			expect(url).to be_equal(relative)
		end
		
		it "raises error for invalid input type" do
			expect do
				Protocol::URL[123]
			end.to raise_exception(ArgumentError, message: be =~ /Cannot coerce/)
		end
		
		it "rejects strings with whitespace" do
			expect do
				Protocol::URL[" "]
			end.to raise_exception(ArgumentError, message: be =~ /Invalid URL.*whitespace/)
		end
		
		it "rejects strings with control characters" do
			expect do
				Protocol::URL["\r\n"]
			end.to raise_exception(ArgumentError, message: be =~ /Invalid URL.*control characters/)
		end
	end
end
