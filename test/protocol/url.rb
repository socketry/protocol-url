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
			expect(url.authority).to be == "//cdn.example.com"
			expect(url.path).to be == "/npm/"
		end
		
		it "coerces protocol-relative URLs" do
			url = Protocol::URL["//cdn.example.com/npm/"]
			expect(url).to be_a(Protocol::URL::Absolute)
			expect(url.scheme).to be == nil
			expect(url.authority).to be == "//cdn.example.com"
			expect(url.path).to be == "/npm/"
		end
		
		it "coerces relative paths" do
			url = Protocol::URL["/_components/"]
			expect(url).to be_a(Protocol::URL::Relative)
			expect(url.path).to be == "/_components/"
		end
	end
end
