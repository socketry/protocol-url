# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "protocol/url"
require "json"

describe Protocol::URL::Relative do
	it "creates a relative URL" do
		url = Protocol::URL::Relative.new("/_components/")
		expect(url.path).to be == Protocol::URL::Path["/_components/"]
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
	
	with "#freeze" do
		it "freezes the URL and its direct components" do
			path = Protocol::URL::Path["/a/../b"]
			query = +"q=test"
			fragment = +"section"
			url = Protocol::URL::Relative.new(path, query, fragment)
			
			expect(url.freeze).to be_equal(url)
			expect(url).to be(:frozen?)
			expect(path).to be(:frozen?)
			expect(query).to be(:frozen?)
			expect(fragment).to be(:frozen?)
			expect(url.freeze).to be_equal(url)
			
			expect do
				path.simplify!
			end.to raise_exception(FrozenError)
		end
		
		it "prevents path assignment" do
			url = Protocol::URL::Relative.new("/original")
			url.freeze
			
			expect do
				url.path = "/updated"
			end.to raise_exception(FrozenError)
		end
		
		it "prevents query and fragment assignment" do
			url = Protocol::URL::Relative.new("/original")
			url.freeze
			
			expect do
				url.query = "q=test"
			end.to raise_exception(FrozenError)
			
			expect do
				url.fragment = "section"
			end.to raise_exception(FrozenError)
		end
	end
	
	with "#path=" do
		it "replaces and coerces the path" do
			url = Protocol::URL::Relative.new("/original", "q=test", "section")
			url.path = "/updated"
			
			expect(url.path).to be == Protocol::URL::Path["/updated"]
			expect(url.query).to be == "q=test"
			expect(url.fragment).to be == "section"
		end
		
		it "assigns an existing path" do
			url = Protocol::URL::Relative.new("/original")
			path = Protocol::URL::Path["/updated"]
			
			url.path = path
			
			expect(url.path).to be_equal(path)
		end
	end
	
	with "component assignment" do
		it "replaces and clears the query" do
			url = Protocol::URL::Relative.new("/search", "q=ruby", "results")
			url.query = "q=python"
			
			expect(url.to_s).to be == "/search?q=python#results"
			
			url.query = nil
			expect(url.to_s).to be == "/search#results"
		end
		
		it "replaces and clears the fragment" do
			url = Protocol::URL::Relative.new("/search", "q=ruby", "old")
			url.fragment = "new"
			
			expect(url.to_s).to be == "/search?q=ruby#new"
			
			url.fragment = nil
			expect(url.to_s).to be == "/search?q=ruby"
		end
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
			expect(result.path).to be == Protocol::URL::Path["/base/path.html"]
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
			expect(updated.path).to be == Protocol::URL::Path["/api/groups"]
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
	
	with "#relative_to" do
		it "makes root-relative URLs relative to a path" do
			url = Protocol::URL::Relative.new("/docs/guide", "q=ruby", "examples")
			result = url.relative_to("/docs/index")
			
			expect(result).to be_a(Protocol::URL::Relative)
			expect(result.path).to be == Protocol::URL::Path["guide"]
			expect(result.query).to be == "q=ruby"
			expect(result.fragment).to be == "examples"
		end
		
		it "accepts a URL as the base" do
			url = Protocol::URL::Relative.new("/docs/guide")
			base = Protocol::URL::Relative.new("/docs/index")
			
			expect(url.relative_to(base).path).to be == Protocol::URL::Path["guide"]
		end
		
		it "preserves encoded path segments" do
			url = Protocol::URL::Relative.new("/files/a%2Fb")
			
			expect(url.relative_to("/index").path).to be == Protocol::URL::Path["files/a%2Fb"]
		end
		
		it "identifies the root directory explicitly" do
			url = Protocol::URL::Relative.new("/", "q=ruby", "examples")
			
			expect(url.relative_to("/index").to_s).to be == "./?q=ruby#examples"
		end
		
		it "disambiguates a colon in the first segment" do
			url = Protocol::URL::Relative.new("/docs/this:that")
			relative_url = url.relative_to("/docs/index")
			
			expect(relative_url.to_s).to be == "./this:that"
			expect(Protocol::URL[relative_url.to_s]).to be_a(Protocol::URL::Relative)
		end
		
		it "returns already-relative URLs unchanged" do
			url = Protocol::URL::Relative.new("../guide", "q=ruby", "examples")
			
			expect(url.relative_to("/docs/index")).to be_equal(url)
		end
	end
	
	with "#to_ary" do
		it "returns array representation" do
			url = Protocol::URL::Relative.new("/path", "q=test", "section")
			expect(url.to_ary).to be == [Protocol::URL::Path["/path"], "q=test", "section"]
		end
	end
	
	with "#hash" do
		it "returns hash based on components" do
			url1 = Protocol::URL::Relative.new("/path", "q=test", "section")
			url2 = Protocol::URL::Relative.new("/path", "q=test", "section")
			expect(url1.hash).to be == url2.hash
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
	
	with "#==" do
		it "compares structural equality" do
			url1 = Protocol::URL::Relative.new("/path", "q=test", "section")
			url2 = Protocol::URL::Relative.new("/path", "q=test", "section")
			expect(url1).to be == url2
		end
		
		it "returns false for different URLs" do
			url1 = Protocol::URL::Relative.new("/path")
			url2 = Protocol::URL::Relative.new("/other")
			expect(url1).not.to be == url2
		end
	end
	
	with "#===" do
		it "compares string representations" do
			url = Protocol::URL::Relative.new("/path", "q=test")
			expect(url === "/path?q=test").to be == true
		end
		
		it "allows string to match URL in case statements" do
			path = "/docs"
			url = Protocol::URL::Relative.new("/docs")
			
			result = case path
			when url
				:match
			else
				:no_match
			end
			
			expect(result).to be == :match
		end
	end
	
	with "#to_s" do
		it "preserves minimal relative URLs by default" do
			url = Protocol::URL::Relative.new("guide", "q=ruby", "examples")
			
			expect(url.to_s).to be == "guide?q=ruby#examples"
		end
		
		it "can serialize same-directory URLs explicitly" do
			url = Protocol::URL::Relative.new("guide", "q=ruby", "examples")
			serialized = url.to_s(explicit: true)
			
			expect(serialized).to be == "./guide?q=ruby#examples"
			expect(Protocol::URL[serialized]).to be_a(Protocol::URL::Relative)
		end
		
		it "can explicitly serialize a normalized combined URL" do
			base = Protocol::URL::Relative.new("./_components/")
			url = base + Protocol::URL::Relative.new("./app.js")
			
			expect(url.to_s).to be == "_components/app.js"
			expect(url.to_s(explicit: true)).to be == "./_components/app.js"
		end
		
		it "preserves parent- and root-relative URLs" do
			expect(Protocol::URL::Relative.new("../guide").to_s(explicit: true)).to be == "../guide"
			expect(Protocol::URL::Relative.new("/guide").to_s(explicit: true)).to be == "/guide"
		end
		
		it "identifies an empty path explicitly" do
			url = Protocol::URL::Relative.new("", "q=ruby", "examples")
			
			expect(url.to_s(explicit: true)).to be == "./?q=ruby#examples"
		end
	end
	
	with "#as_json" do
		it "returns string representation" do
			url = Protocol::URL::Relative.new("/path", "q=test", "section")
			expect(url.as_json).to be == "/path?q=test#section"
		end
	end
	
	with "#to_json" do
		it "returns JSON string representation" do
			url = Protocol::URL::Relative.new("/path", "q=test", "section")
			expect(url.to_json).to be == '"/path?q=test#section"'
		end
	end
	
	with "#normalize!" do
		it "normalizes the encoded path" do
			url = Protocol::URL::Relative.new("/%66oo/a%2fb")
			url.normalize!
			expect(url.path).to be == Protocol::URL::Path["/foo/a%2Fb"]
		end
		
		it "simplifies normalized dot segments" do
			url = Protocol::URL::Relative.new("/foo/%2e%2e/bar")
			url.normalize!
			expect(url.path).to be == Protocol::URL::Path["/bar"]
		end
		
		it "removes dot segments" do
			url = Protocol::URL::Relative.new("/foo/./bar")
			url.normalize!
			expect(url.path).to be == Protocol::URL::Path["/foo/bar"]
		end
		
		it "resolves parent directory segments" do
			url = Protocol::URL::Relative.new("/foo/bar/../baz")
			url.normalize!
			expect(url.path).to be == Protocol::URL::Path["/foo/baz"]
		end
		
		it "collapses empty path segments" do
			url = Protocol::URL::Relative.new("/foo//bar///baz")
			url.normalize!
			expect(url.path).to be == Protocol::URL::Path["/foo/bar/baz"]
		end
		
		it "handles complex paths" do
			url = Protocol::URL::Relative.new("/foo//bar/./baz/../qux")
			url.normalize!
			expect(url.path).to be == Protocol::URL::Path["/foo/bar/qux"]
		end
		
		it "preserves trailing slash" do
			url = Protocol::URL::Relative.new("/foo/bar/")
			url.normalize!
			expect(url.path).to be == Protocol::URL::Path["/foo/bar/"]
		end
		
		it "handles relative paths" do
			url = Protocol::URL::Relative.new("foo/bar/../baz")
			url.normalize!
			expect(url.path).to be == Protocol::URL::Path["foo/baz"]
		end
		
		it "returns self" do
			url = Protocol::URL::Relative.new("/foo/bar")
			result = url.normalize!
			expect(result).to be_equal(url)
		end
		
		it "preserves query and fragment" do
			url = Protocol::URL::Relative.new("/foo//bar", "q=test", "section")
			url.normalize!
			expect(url.path).to be == Protocol::URL::Path["/foo/bar"]
			expect(url.query).to be == "q=test"
			expect(url.fragment).to be == "section"
		end
	end
	
	with "#local_path" do
		let(:root) {File.expand_path("public", Dir.pwd)}
		
		it "converts path to local file system path" do
			url = Protocol::URL::Relative.new("/documents/report.pdf")
			expect(url.local_path(root)).to be == File.join(root, "documents", "report.pdf")
		end
		
		it "handles percent-encoded characters" do
			url = Protocol::URL::Relative.new("/files/My%20Document.txt")
			expect(url.local_path(root)).to be == File.join(root, "files", "My Document.txt")
		end
		
		it "handles unicode characters" do
			url = Protocol::URL::Relative.new("/files/%E2%9D%A4%EF%B8%8F.txt")
			expect(url.local_path(root)).to be == File.join(root, "files", "❤️.txt")
		end
		
		it "rejects encoded path separators" do
			url = Protocol::URL::Relative.new("/safe%2Fname/file.txt")
			expect do
				url.local_path(root)
			end.to raise_exception(ArgumentError, message: be =~ /invalid characters/)
		end
	end
end
