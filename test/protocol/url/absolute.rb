# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "protocol/url"

describe Protocol::URL::Absolute do
	it "creates an absolute URL" do
		url = Protocol::URL::Absolute.new("https", "cdn.example.com", "/npm/")
		expect(url.scheme).to be == "https"
		expect(url.authority).to be == "cdn.example.com"
		expect(url.path).to be == Protocol::URL::Path["/npm/"]
		expect(url.to_s).to be == "https://cdn.example.com/npm/"
	end
	
	it "concatenates with a relative path" do
		base = Protocol::URL::Absolute.new("https", "cdn.example.com", "/npm/")
		relative = Protocol::URL::Relative.new("lit@2.7.5/index.js")
		result = base + relative
		expect(result).to be_a(Protocol::URL::Absolute)
		expect(result.to_s).to be == "https://cdn.example.com/npm/lit@2.7.5/index.js"
	end
	
	with "#freeze" do
		it "freezes the scheme and authority" do
			scheme = +"https"
			authority = +"example.com"
			url = Protocol::URL::Absolute.new(scheme, authority, "/")
			
			expect(url.freeze).to be_equal(url)
			expect(url).to be(:frozen?)
			expect(scheme).to be(:frozen?)
			expect(authority).to be(:frozen?)
			expect(url.path).to be(:frozen?)
			expect(url.freeze).to be_equal(url)
		end
		
		it "prevents scheme and authority assignment" do
			url = Protocol::URL::Absolute.new("https", "example.com", "/")
			url.freeze
			
			expect do
				url.scheme = "http"
			end.to raise_exception(FrozenError)
			
			expect do
				url.authority = "other.example.com"
			end.to raise_exception(FrozenError)
		end
	end
	
	with "#path=" do
		it "replaces the path while preserving the origin" do
			url = Protocol::URL::Absolute.new("https", "example.com", "/original", "q=test", "section")
			url.path = "/updated"
			
			expect(url.to_s).to be == "https://example.com/updated?q=test#section"
		end
	end
	
	with "component assignment" do
		it "replaces and clears the scheme" do
			url = Protocol::URL::Absolute.new("http", "example.com", "/path")
			url.scheme = "https"
			
			expect(url.to_s).to be == "https://example.com/path"
			
			url.scheme = nil
			expect(url.to_s).to be == "//example.com/path"
		end
		
		it "replaces and clears the authority" do
			url = Protocol::URL::Absolute.new("https", "example.com", "/path")
			url.authority = "cdn.example.com"
			
			expect(url.to_s).to be == "https://cdn.example.com/path"
			
			url.authority = nil
			expect(url.to_s).to be == "https:/path"
		end
	end
	
	describe "fragment handling" do
		it "preserves encoded fragments" do
			url = Protocol::URL["http://example.com/path#hello%20world"]
			expect(url.fragment).to be == "hello%20world"
			expect(url.to_s).to be == "http://example.com/path#hello%20world"
		end
		
		it "preserves all encoded characters" do
			url = Protocol::URL["http://example.com/path#hello%3C%3E"]
			expect(url.fragment).to be == "hello%3C%3E"
			expect(url.to_s).to be == "http://example.com/path#hello%3C%3E"
		end
		
		it "preserves allowed fragment characters" do
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
			expect(result.path).to be == Protocol::URL::Path["/lib.js"]
		end
		
		it "handles Reference argument" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/path")
			reference = Protocol::URL::Reference.new("other.html", nil, nil, nil)
			result = base + reference
			expect(result.path).to be == Protocol::URL::Path["/other.html"]
		end
		
		it "raises error for invalid type" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/path")
			expect do
				base + 123
			end.to raise_exception(ArgumentError, message: be =~ /Cannot combine/)
		end
	end
	
	with "#scheme?" do
		it "returns true when scheme is present" do
			url = Protocol::URL::Absolute.new("https", "example.com", "/")
			expect(url).to be(:scheme?)
		end
		
		it "returns false when scheme is nil" do
			url = Protocol::URL::Absolute.new(nil, "example.com", "/")
			expect(url).not.to be(:scheme?)
		end
	end
	
	with "#authority?" do
		it "returns true when authority is present" do
			url = Protocol::URL::Absolute.new("https", "example.com", "/")
			expect(url).to be(:authority?)
		end
		
		it "returns false when authority is nil" do
			url = Protocol::URL::Absolute.new("https", nil, "/path")
			expect(url).not.to be(:authority?)
		end
	end
	
	with "#with" do
		it "updates scheme" do
			base = Protocol::URL::Absolute.new("http", "example.com", "/")
			updated = base.with(scheme: "https")
			expect(updated.scheme).to be == "https"
		end
		
		it "updates authority" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/")
			updated = base.with(authority: "other.com")
			expect(updated.authority).to be == "other.com"
		end
		
		it "merges path" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/api")
			updated = base.with(path: "users")
			expect(updated.path).to be == Protocol::URL::Path["/users"]
		end
		
		it "updates query" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/", "q=ruby")
			updated = base.with(query: "q=python")
			expect(updated.query).to be == "q=python"
		end
		
		it "updates fragment" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/", nil, "intro")
			updated = base.with(fragment: "advanced")
			expect(updated.fragment).to be == "advanced"
		end
		
		it "preserves existing values when not specified" do
			base = Protocol::URL::Absolute.new("https", "example.com", "/path", "q=test", "section")
			updated = base.with(path: "other")
			expect(updated.scheme).to be == "https"
			expect(updated.authority).to be == "example.com"
			expect(updated.query).to be == "q=test"
			expect(updated.fragment).to be == "section"
		end
	end
	
	with "#relative_to" do
		it "returns absolute URLs unchanged" do
			url = Protocol::URL::Absolute.new("https", "example.com", "/docs/guide", "q=ruby", "examples")
			
			expect(url.relative_to("/docs/index")).to be_equal(url)
		end
	end
	
	with "#to_ary" do
		it "returns array representation" do
			url = Protocol::URL::Absolute.new("https", "example.com", "/path", "q=test", "section")
			expect(url.to_ary).to be == ["https", "example.com", Protocol::URL::Path["/path"], "q=test", "section"]
		end
	end
	
	with "#<=>" do
		it "compares URLs" do
			url1 = Protocol::URL::Absolute.new("https", "a.com", "/")
			url2 = Protocol::URL::Absolute.new("https", "b.com", "/")
			expect(url1 <=> url2).to be == -1
			expect(url2 <=> url1).to be == 1
			expect(url1 <=> url1).to be == 0
		end
	end
	
	with "#local_path" do
		let(:root) {File.expand_path("public", Dir.pwd)}
		
		it "converts path to local file system path" do
			url = Protocol::URL::Absolute.new("https", "example.com", "/documents/report.pdf")
			expect(url.local_path(root)).to be == File.join(root, "documents", "report.pdf")
		end
		
		it "handles percent-encoded characters" do
			url = Protocol::URL::Absolute.new("https", "example.com", "/files/My%20Document.txt")
			expect(url.local_path(root)).to be == File.join(root, "files", "My Document.txt")
		end
		
		it "only converts the path component" do
			url = Protocol::URL::Absolute.new("https", "example.com", "/api/users", "page=2", "results")
			# Query and fragment are not included in local path
			expect(url.local_path(root)).to be == File.join(root, "api", "users")
		end
	end
end
