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
	
	with ".to_local_path" do
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
			it "preserves %2F (encoded forward slash)" do
				# %2F is the encoded form of /
				# Preserving it prevents creating additional path components
				result = Protocol::URL::Path.to_local_path("/folder/safe%2Fname/file.txt")
				expect(result).to be == "/folder/safe%2Fname/file.txt"
			end
			
			it "preserves %5C (encoded backslash)" do
				# %5C is the encoded form of \
				# Preserving it prevents creating path separators on Windows
				result = Protocol::URL::Path.to_local_path("/folder/name%5Cfile.txt")
				expect(result).to be == "/folder/name%5Cfile.txt"
			end
			
			it "preserves multiple encoded separators" do
				# Multiple %2F should all be preserved
				result = Protocol::URL::Path.to_local_path("/a%2Fb%2Fc/d.txt")
				expect(result).to be == "/a%2Fb%2Fc/d.txt"
			end
			
			it "preserves encoded separators while decoding other characters" do
				# %20 (space) should be decoded, %2F should be preserved
				result = Protocol::URL::Path.to_local_path("/folder/My%20File%2Fname.txt")
				expect(result).to be == "/folder/My File%2Fname.txt"
			end
			
			it "allows encoded dots (not path traversal when literal)" do
				# %2E is the encoded form of .
				# Two of them (%2E%2E) as literal characters are fine - they're not ".."
				result = Protocol::URL::Path.to_local_path("/folder/%2E%2E/file.txt")
				expect(result).to be == "/folder/../file.txt"
			end
		end
		
		with "edge cases" do
			it "handles multiple consecutive slashes" do
				# Multiple slashes create empty components, File.join collapses them
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
