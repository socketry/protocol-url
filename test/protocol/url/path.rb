# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/url/path"

describe Protocol::URL::Path do
	with ".split" do
		it "splits empty path" do
			expect(Protocol::URL::Path.split("")).to be == []
		end
		
		it "splits root path" do
			expect(Protocol::URL::Path.split("/")).to be == ["", ""]
		end
		
		it "splits absolute path" do
			expect(Protocol::URL::Path.split("/a/b/c")).to be == ["", "a", "b", "c"]
		end
		
		it "splits relative path" do
			expect(Protocol::URL::Path.split("a/b/c")).to be == ["a", "b", "c"]
		end
		
		it "splits path with trailing slash" do
			expect(Protocol::URL::Path.split("a/b/c/")).to be == ["a", "b", "c", ""]
		end
		
		it "splits absolute path with trailing slash" do
			expect(Protocol::URL::Path.split("/a/b/c/")).to be == ["", "a", "b", "c", ""]
		end
		
		it "splits path with multiple slashes" do
			expect(Protocol::URL::Path.split("a//b///c")).to be == ["a", "", "b", "", "", "c"]
		end
	end
	
	with ".join" do
		it "joins empty array" do
			expect(Protocol::URL::Path.join([])).to be == ""
		end
		
		it "joins root components" do
			expect(Protocol::URL::Path.join(["", ""])).to be == "/"
		end
		
		it "joins absolute path components" do
			expect(Protocol::URL::Path.join(["", "a", "b", "c"])).to be == "/a/b/c"
		end
		
		it "joins relative path components" do
			expect(Protocol::URL::Path.join(["a", "b", "c"])).to be == "a/b/c"
		end
		
		it "joins path with trailing slash" do
			expect(Protocol::URL::Path.join(["a", "b", "c", ""])).to be == "a/b/c/"
		end
	end
	
	with ".simplify" do
		it "simplifies empty path" do
			expect(Protocol::URL::Path.simplify([])).to be == []
		end
		
		it "simplifies root path" do
			expect(Protocol::URL::Path.simplify(["", ""])).to be == ["", ""]
		end
		
		it "preserves simple absolute path" do
			expect(Protocol::URL::Path.simplify(["", "a", "b", "c"])).to be == ["", "a", "b", "c"]
		end
		
		it "preserves simple relative path" do
			expect(Protocol::URL::Path.simplify(["a", "b", "c"])).to be == ["a", "b", "c"]
		end
		
		it "removes current directory at start" do
			expect(Protocol::URL::Path.simplify([".", "a", "b"])).to be == ["a", "b"]
		end
		
		it "removes current directory in middle" do
			expect(Protocol::URL::Path.simplify(["a", ".", "b"])).to be == ["a", "b"]
		end
		
		it "adds trailing slash for trailing dot" do
			expect(Protocol::URL::Path.simplify(["a", "b", "."])).to be == ["a", "b", ""]
		end
		
		it "removes multiple slashes" do
			expect(Protocol::URL::Path.simplify(["a", "", "b", "", "", "c"])).to be == ["a", "b", "c"]
		end
		
		it "preserves trailing empty component" do
			expect(Protocol::URL::Path.simplify(["a", "b", ""])).to be == ["a", "b", ""]
		end
		
		it "resolves parent directory" do
			expect(Protocol::URL::Path.simplify(["a", "b", "..", "c"])).to be == ["a", "c"]
		end
		
		it "resolves multiple parent directories" do
			expect(Protocol::URL::Path.simplify(["a", "b", "c", "..", "..", "d"])).to be == ["a", "d"]
		end
		
		it "adds trailing slash for trailing parent directory" do
			expect(Protocol::URL::Path.simplify(["a", "b", ".."])).to be == ["a", ""]
		end
		
		it "resolves parent at absolute root" do
			expect(Protocol::URL::Path.simplify(["", "a", ".."])).to be == ["", ""]
		end
		
		it "cannot go above absolute root" do
			expect(Protocol::URL::Path.simplify(["", "..", "a"])).to be == ["", "a"]
		end
		
		it "preserves parent directory at relative root" do
			expect(Protocol::URL::Path.simplify(["..", "a"])).to be == ["..", "a"]
		end
		
		it "preserves multiple parent directories at relative root" do
			expect(Protocol::URL::Path.simplify(["..", "..", "a"])).to be == ["..", "..", "a"]
		end
		
		it "cannot remove parent directory markers" do
			expect(Protocol::URL::Path.simplify(["a", "..", "..", "b"])).to be == ["..", "b"]
		end
		
		it "handles complex path" do
			expect(Protocol::URL::Path.simplify(["", "a", "b", ".", "c", "..", "d", "", "e"])).to be == ["", "a", "b", "d", "e"]
		end
		
		it "resolves all dots and double dots" do
			expect(Protocol::URL::Path.simplify([".", "a", ".", "b", "..", "c", ".", "d", ".."])).to be == ["a", "c", ""]
		end
	end
	
	with ".parse" do
		it "parses absolute paths into canonical components" do
			expect(Protocol::URL::Path.parse("/a//b/./c/../d")).to be == ["", "a", "b", "d"]
			expect(Protocol::URL::Path.parse("/a/../b/")).to be == ["", "b", ""]
		end
		
		it "prevents protocol-relative paths" do
			expect(Protocol::URL::Path.parse("//example.com/index")).to be == ["", "example.com", "index"]
		end
		
		it "canonicalizes percent escapes without changing reserved characters" do
			expect(Protocol::URL::Path.parse("/a+b/%7euser/%3f")).to be == ["", "a+b", "~user", "%3F"]
		end
		
		it "accepts the RFC 3986 path character grammar" do
			expect(Protocol::URL::Path.parse("AZaz09-._~!$&'()*+,;=:@")).to be == ["AZaz09-._~!$&'()*+,;=:@"]
		end
		
		it "preserves percent-encoded non-ASCII bytes" do
			expect(Protocol::URL::Path.parse("/caf%c3%a9")).to be == ["", "caf%C3%A9"]
		end
		
		it "resolves encoded dot segments" do
			expect(Protocol::URL::Path.parse("/a/%2e%2e/b")).to be == ["", "b"]
		end
		
		it "does not decode percent escapes more than once" do
			expect(Protocol::URL::Path.parse("/%252e%252e/value")).to be == ["", "%252e%252e", "value"]
		end
		
		it "parses and simplifies relative paths" do
			expect(Protocol::URL::Path.parse("a/../b")).to be == ["b"]
			expect(Protocol::URL::Path.parse("../a")).to be == ["..", "a"]
			expect(Protocol::URL::Path.parse("a/../../b")).to be == ["..", "b"]
			expect(Protocol::URL::Path.parse("a/..")).to be == []
			expect(Protocol::URL::Path.parse(".")).to be == []
		end
		
		it "rejects traversal above the root" do
			expect do
				Protocol::URL::Path.parse("/../../etc/passwd")
			end.to raise_exception(
				Protocol::URL::InvalidPathError,
				message: be == 'URL path "/../../etc/passwd" could not be parsed because it traverses above the root!'
			)
			
			expect do
				Protocol::URL::Path.parse("/%2e%2e/etc/passwd")
			end.to raise_exception(Protocol::URL::InvalidPathError)
		end
		
		it "preserves encoded separators within their components" do
			expect(Protocol::URL::Path.parse("/a%2fb")).to be == ["", "a%2Fb"]
			expect(Protocol::URL::Path.parse("/a%5cb")).to be == ["", "a%5Cb"]
		end
		
		it "rejects malformed percent escapes" do
			expect do
				Protocol::URL::Path.parse("/invalid%2")
			end.to raise_exception(Protocol::URL::InvalidPathError)
		end
		
		it "rejects characters outside the RFC 3986 path grammar" do
			[" ", '"', "<", ">", "[", "]", "^", "`", "{", "|", "}"].each do |character|
				expect do
					Protocol::URL::Path.parse("/invalid#{character}path")
				end.to raise_exception(Protocol::URL::InvalidPathError)
			end
		end
		
		it "rejects raw non-ASCII bytes with a structured error" do
			["/café", "/invalid\xFF".b.force_encoding(Encoding::UTF_8)].each do |path|
				expect do
					Protocol::URL::Path.parse(path)
				end.to raise_exception(Protocol::URL::InvalidPathError)
			end
		end
		
		it "rejects query and fragment delimiters" do
			expect do
				Protocol::URL::Path.parse("/search?query=test")
			end.to raise_exception(Protocol::URL::InvalidPathError)
			
			expect do
				Protocol::URL::Path.parse("/document#section")
			end.to raise_exception(Protocol::URL::InvalidPathError)
		end
		
		it "rejects raw ambiguous separators" do
			expect do
				Protocol::URL::Path.parse("/a\\b")
			end.to raise_exception(Protocol::URL::InvalidPathError)
		end
		
		it "rejects raw null bytes and preserves encoded null bytes" do
			expect do
				Protocol::URL::Path.parse("/a\0b")
			end.to raise_exception(Protocol::URL::InvalidPathError)
			
			expect(Protocol::URL::Path.parse("/a%00b")).to be == ["", "a%00b"]
		end
	end
	
	with ".expand" do
		with "empty relative path" do
			it "returns base path unchanged" do
				expect(Protocol::URL::Path.expand("/foo/bar", "")).to be == "/foo/bar"
			end
			
			it "returns relative base path unchanged" do
				expect(Protocol::URL::Path.expand("foo/bar", "")).to be == "foo/bar"
			end
		end
		
		with "absolute relative path" do
			it "replaces base with absolute path" do
				expect(Protocol::URL::Path.expand("/base/path", "/new/path")).to be == "/new/path"
			end
			
			it "replaces relative base with absolute path" do
				expect(Protocol::URL::Path.expand("base/path", "/new/path")).to be == "/new/path"
			end
		end
		
		with "simple relative paths" do
			it "appends to absolute base (pops last component by default)" do
				expect(Protocol::URL::Path.expand("/base", "file")).to be == "/file"
			end
			
			it "appends to relative base (pops last component by default)" do
				expect(Protocol::URL::Path.expand("base", "file")).to be == "file"
			end
			
			it "appends multiple components (pops last component by default)" do
				expect(Protocol::URL::Path.expand("/base", "a/b/c")).to be == "/a/b/c"
			end
		end
		
		with "pop parameter" do
			it "pops last component when pop=true (default)" do
				expect(Protocol::URL::Path.expand("/a/b/c", "d")).to be == "/a/b/d"
			end
			
			it "does not pop when pop=false" do
				expect(Protocol::URL::Path.expand("/a/b/c", "d", false)).to be == "/a/b/c/d"
			end
			
			it "pops last component for relative base" do
				expect(Protocol::URL::Path.expand("a/b/c", "d")).to be == "a/b/d"
			end
			
			it "does not pop parent directory marker" do
				expect(Protocol::URL::Path.expand("/a/..", "c")).to be == "/c"
			end
		end
		
		with "dot segments in relative path" do
			it "resolves current directory" do
				expect(Protocol::URL::Path.expand("/a/b", "./c")).to be == "/a/c"
			end
			
			it "resolves parent directory" do
				expect(Protocol::URL::Path.expand("/a/b/c", "../d")).to be == "/a/d"
			end
			
			it "resolves multiple parent directories" do
				expect(Protocol::URL::Path.expand("/a/b/c/d", "../../e")).to be == "/a/e"
			end
			
			it "resolves trailing dot" do
				expect(Protocol::URL::Path.expand("/a/b", ".")).to be == "/a/"
			end
			
			it "resolves trailing parent directory" do
				expect(Protocol::URL::Path.expand("/a/b/c", "..")).to be == "/a/"
			end
		end
		
		with "trailing slashes" do
			it "preserves trailing slash from base" do
				expect(Protocol::URL::Path.expand("/a/b/", "c")).to be == "/a/b/c"
			end
			
			it "preserves trailing slash from relative" do
				expect(Protocol::URL::Path.expand("/a/b", "c/")).to be == "/a/c/"
			end
			
			it "adds trailing slash for relative ending with dot" do
				expect(Protocol::URL::Path.expand("/a/b", "c/.")).to be == "/a/c/"
			end
			
			it "adds trailing slash for relative ending with parent" do
				expect(Protocol::URL::Path.expand("/a/b/c", "d/..")).to be == "/a/b/"
			end
		end
		
		with "RFC 3986 examples" do
			let(:base) {"/a/b/c/d;p"}
			
			it "resolves 'g'" do
				expect(Protocol::URL::Path.expand(base, "g")).to be == "/a/b/c/g"
			end
			
			it "resolves './g'" do
				expect(Protocol::URL::Path.expand(base, "./g")).to be == "/a/b/c/g"
			end
			
			it "resolves 'g/'" do
				expect(Protocol::URL::Path.expand(base, "g/")).to be == "/a/b/c/g/"
			end
			
			it "resolves '/g'" do
				expect(Protocol::URL::Path.expand(base, "/g")).to be == "/g"
			end
			
			it "resolves 'g?y'" do
				expect(Protocol::URL::Path.expand(base, "g?y")).to be == "/a/b/c/g?y"
			end
			
			it "resolves '#s'" do
				expect(Protocol::URL::Path.expand(base, "#s")).to be == "/a/b/c/#s"
			end
			
			it "resolves 'g#s'" do
				expect(Protocol::URL::Path.expand(base, "g#s")).to be == "/a/b/c/g#s"
			end
			
			it "resolves 'g?y#s'" do
				expect(Protocol::URL::Path.expand(base, "g?y#s")).to be == "/a/b/c/g?y#s"
			end
			
			it "resolves ';x'" do
				expect(Protocol::URL::Path.expand(base, ";x")).to be == "/a/b/c/;x"
			end
			
			it "resolves 'g;x'" do
				expect(Protocol::URL::Path.expand(base, "g;x")).to be == "/a/b/c/g;x"
			end
			
			it "resolves 'g;x?y#s'" do
				expect(Protocol::URL::Path.expand(base, "g;x?y#s")).to be == "/a/b/c/g;x?y#s"
			end
			
			it "resolves ''" do
				expect(Protocol::URL::Path.expand(base, "")).to be == "/a/b/c/d;p"
			end
			
			it "resolves '.'" do
				expect(Protocol::URL::Path.expand(base, ".")).to be == "/a/b/c/"
			end
			
			it "resolves './'" do
				expect(Protocol::URL::Path.expand(base, "./")).to be == "/a/b/c/"
			end
			
			it "resolves '..'" do
				expect(Protocol::URL::Path.expand(base, "..")).to be == "/a/b/"
			end
			
			it "resolves '../'" do
				expect(Protocol::URL::Path.expand(base, "../")).to be == "/a/b/"
			end
			
			it "resolves '../g'" do
				expect(Protocol::URL::Path.expand(base, "../g")).to be == "/a/b/g"
			end
			
			it "resolves '../..'" do
				expect(Protocol::URL::Path.expand(base, "../..")).to be == "/a/"
			end
			
			it "resolves '../../'" do
				expect(Protocol::URL::Path.expand(base, "../../")).to be == "/a/"
			end
			
			it "resolves '../../g'" do
				expect(Protocol::URL::Path.expand(base, "../../g")).to be == "/a/g"
			end
		end
		
		with "abnormal RFC 3986 examples" do
			let(:base) {"/a/b/c/d;p"}
			
			it "resolves '../../../g'" do
				expect(Protocol::URL::Path.expand(base, "../../../g")).to be == "/g"
			end
			
			it "resolves '../../../../g'" do
				expect(Protocol::URL::Path.expand(base, "../../../../g")).to be == "/g"
			end
			
			it "resolves '/./g'" do
				expect(Protocol::URL::Path.expand(base, "/./g")).to be == "/g"
			end
			
			it "resolves '/../g'" do
				expect(Protocol::URL::Path.expand(base, "/../g")).to be == "/g"
			end
			
			it "resolves 'g.'" do
				expect(Protocol::URL::Path.expand(base, "g.")).to be == "/a/b/c/g."
			end
			
			it "resolves '.g'" do
				expect(Protocol::URL::Path.expand(base, ".g")).to be == "/a/b/c/.g"
			end
			
			it "resolves 'g..'" do
				expect(Protocol::URL::Path.expand(base, "g..")).to be == "/a/b/c/g.."
			end
			
			it "resolves '..g'" do
				expect(Protocol::URL::Path.expand(base, "..g")).to be == "/a/b/c/..g"
			end
			
			it "resolves './../g'" do
				expect(Protocol::URL::Path.expand(base, "./../g")).to be == "/a/b/g"
			end
			
			it "resolves './g/.'" do
				expect(Protocol::URL::Path.expand(base, "./g/.")).to be == "/a/b/c/g/"
			end
			
			it "resolves 'g/./h'" do
				expect(Protocol::URL::Path.expand(base, "g/./h")).to be == "/a/b/c/g/h"
			end
			
			it "resolves 'g/../h'" do
				expect(Protocol::URL::Path.expand(base, "g/../h")).to be == "/a/b/c/h"
			end
			
			it "resolves 'g;x=1/./y'" do
				expect(Protocol::URL::Path.expand(base, "g;x=1/./y")).to be == "/a/b/c/g;x=1/y"
			end
			
			it "resolves 'g;x=1/../y'" do
				expect(Protocol::URL::Path.expand(base, "g;x=1/../y")).to be == "/a/b/c/y"
			end
		end
		
		with "edge cases" do
			it "handles empty base path" do
				expect(Protocol::URL::Path.expand("", "foo")).to be == "foo"
			end
			
			it "handles root base path" do
				expect(Protocol::URL::Path.expand("/", "foo")).to be == "/foo"
			end
			
			it "handles multiple slashes in relative" do
				expect(Protocol::URL::Path.expand("/a/b", "c//d")).to be == "/a/c/d"
			end
			
			it "handles multiple slashes in base" do
				expect(Protocol::URL::Path.expand("/a//b", "c")).to be == "/a/c"
			end
			
			it "resolves complex mix of dots and paths" do
				expect(Protocol::URL::Path.expand("/a/b/c", "./../d/./e/../f")).to be == "/a/d/f"
			end
		end
	end
	
	with ".relative" do
		it "calculates relative path between pages" do
			expect(Protocol::URL::Path.relative("/_components/app.js", "/foo/bar/")).to be == "../../_components/app.js"
		end
		
		it "calculates relative path in same directory" do
			expect(Protocol::URL::Path.relative("/docs/guide.html", "/docs/index.html")).to be == "guide.html"
		end
		
		it "calculates relative path from root to subdirectory" do
			expect(Protocol::URL::Path.relative("/foo/bar/", "/")).to be == "foo/bar/"
		end
		
		it "calculates relative path to parent directory" do
			expect(Protocol::URL::Path.relative("/docs/", "/docs/api/reference.html")).to be == "../"
		end
		
		it "calculates relative path with multiple levels up" do
			expect(Protocol::URL::Path.relative("/a/file.txt", "/x/y/z/")).to be == "../../../a/file.txt"
		end
		
		it "calculates relative path with common prefix" do
			expect(Protocol::URL::Path.relative("/projects/alpha/file.txt", "/projects/beta/")).to be == "../alpha/file.txt"
		end
		
		it "preserves trailing slashes in target" do
			expect(Protocol::URL::Path.relative("/foo/bar/", "/baz/")).to be == "../foo/bar/"
		end
		
		it "handles target without trailing slash" do
			expect(Protocol::URL::Path.relative("/foo/bar", "/baz/")).to be == "../foo/bar"
		end
	end
	
	with ".to_local_path" do
		it "converts parsed components" do
			components = Protocol::URL::Path.parse("/documents/report.pdf")
			expect(Protocol::URL::Path.to_local_path(components)).to be == "/documents/report.pdf"
		end
		
		it "converts simple absolute path" do
			result = Protocol::URL::Path.to_local_path("/documents/report.pdf")
			expect(result).to be == "/documents/report.pdf"
		end
		
		it "converts simple relative path" do
			result = Protocol::URL::Path.to_local_path("documents/report.pdf")
			expect(result).to be == "documents/report.pdf"
		end
		
		it "unescapes percent-encoded characters" do
			result = Protocol::URL::Path.to_local_path("/files/My%20Document.txt")
			expect(result).to be == "/files/My Document.txt"
		end
		
		it "unescapes unicode characters" do
			result = Protocol::URL::Path.to_local_path("/files/%E2%9D%A4%EF%B8%8F.txt")
			expect(result).to be == "/files/❤️.txt"
		end
		
		it "preserves empty path" do
			result = Protocol::URL::Path.to_local_path("")
			expect(result).to be == ""
		end
		
		it "converts root path" do
			result = Protocol::URL::Path.to_local_path("/")
			expect(result).to be == "/"
		end
		
		it "handles path with trailing slash" do
			result = Protocol::URL::Path.to_local_path("/documents/folder/")
			expect(result).to be == "/documents/folder/"
		end
		
		with "security: encoded path separators" do
			it "rejects encoded forward slashes" do
				expect do
					Protocol::URL::Path.to_local_path("/folder/safe%2Fname/file.txt")
				end.to raise_exception(
					Protocol::URL::InvalidPathError,
					message: be == 'URL path "/folder/safe%2Fname/file.txt" could not be converted to a local path because it contains an encoded local path separator!'
				)
			end
			
			if File::ALT_SEPARATOR
				it "rejects encoded backslashes on platforms where they are separators" do
					expect do
						Protocol::URL::Path.to_local_path("/folder/name%5Cfile.txt")
					end.to raise_exception(Protocol::URL::InvalidPathError)
				end
			else
				it "decodes encoded backslashes when they are not separators" do
					expect(Protocol::URL::Path.to_local_path("/folder/name%5Cfile.txt")).to be == "/folder/name\\file.txt"
				end
			end
			
			it "resolves encoded dot segments before conversion" do
				expect(Protocol::URL::Path.to_local_path("/folder/%2E%2E/file.txt")).to be == "/file.txt"
			end
			
			it "rejects encoded null bytes" do
				expect do
					Protocol::URL::Path.to_local_path("/folder/a%00b")
				end.to raise_exception(Protocol::URL::InvalidPathError)
			end
		end
		
		with "edge cases" do
			it "handles multiple consecutive slashes" do
				result = Protocol::URL::Path.to_local_path("/a//b///c")
				expect(result).to be == "/a/b/c"
			end
			
			it "handles special characters in filenames" do
				result = Protocol::URL::Path.to_local_path("/files/name%21%40%23.txt")
				expect(result).to be == "/files/name!@#.txt"
			end
			
			it "handles mixed encoded and unencoded" do
				result = Protocol::URL::Path.to_local_path("/files/My%20Documents/file.txt")
				expect(result).to be == "/files/My Documents/file.txt"
			end
		end
	end
end
