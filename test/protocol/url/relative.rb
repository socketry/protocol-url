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
	
	with "#query?" do
		it "returns true when query is present" do
			url = Protocol::URL::Relative.new("/path", "q=test")
			expect(url).to be(:query?)
		end
		
		it "returns false when query is nil" do
			url = Protocol::URL::Relative.new("/path", nil)
			expect(url).not.to be(:query?)
		end
		
		it "returns false when query is empty" do
			url = Protocol::URL::Relative.new("/path", "")
			expect(url).not.to be(:query?)
		end
	end
	
	with "#fragment?" do
		it "returns true when fragment is present" do
			url = Protocol::URL::Relative.new("/path", nil, "section")
			expect(url).to be(:fragment?)
		end
		
		it "returns false when fragment is nil" do
			url = Protocol::URL::Relative.new("/path", nil, nil)
			expect(url).not.to be(:fragment?)
		end
		
		it "returns false when fragment is empty" do
			url = Protocol::URL::Relative.new("/path", nil, "")
			expect(url).not.to be(:fragment?)
		end
	end
	
	with "#with" do
		it "updates path" do
			base = Protocol::URL::Relative.new("/api/users")
			updated = base.with(path: "groups")
			expect(updated.path).to be == "/api/groups"
		end
		
		it "updates query" do
			base = Protocol::URL::Relative.new("/search", "q=ruby")
			updated = base.with(query: "q=python")
			expect(updated.query).to be == "q=python"
		end
		
		it "updates fragment" do
			base = Protocol::URL::Relative.new("/docs", nil, "intro")
			updated = base.with(fragment: "advanced")
			expect(updated.fragment).to be == "advanced"
		end
		
		it "preserves existing values when not specified" do
			base = Protocol::URL::Relative.new("/path", "q=test", "section")
			updated = base.with(path: "other")
			expect(updated.query).to be == "q=test"
			expect(updated.fragment).to be == "section"
		end
	end
	
	with "#to_ary" do
		it "returns array representation" do
			url = Protocol::URL::Relative.new("/path", "q=test", "section")
			expect(url.to_ary).to be == ["/path", "q=test", "section"]
		end
	end
	
	with "#<=>" do
		it "compares URLs" do
			url1 = Protocol::URL::Relative.new("/a")
			url2 = Protocol::URL::Relative.new("/b")
			expect(url1 <=> url2).to be == -1
			expect(url2 <=> url1).to be == 1
			expect(url1 <=> url1).to be == 0
		end
	end
end
