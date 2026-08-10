# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/url/path"

describe Protocol::URL::Path do
	with ".[]" do
		it "returns an existing path" do
			path = Protocol::URL::Path["/a/b"]
			
			expect(Protocol::URL::Path[path]).to be_equal(path)
		end
		
		it "interprets strings as encoded paths" do
			path = Protocol::URL::Path["/a/b%2Fc"]
			
			expect(path.components).to be == ["", "a", "b/c"]
		end
		
		it "interprets arrays as decoded components" do
			path = Protocol::URL::Path[["", "a", "b/c"]]
			
			expect(path.encoded).to be == "/a/b%2Fc"
		end
		
		it "canonicalizes the absolute root component" do
			path = Protocol::URL::Path[[""]]
			
			expect(path.components).to be == ["", ""]
			expect(path.encoded).to be == "/"
			expect(path).to be == Protocol::URL::Path["/"]
		end
	end
	
	with ".new" do
		it "constructs an empty path without a representation" do
			path = Protocol::URL::Path.new(nil)
			
			expect(path).to be(:empty?)
			expect(path.encoded).to be == ""
		end
	end
	
	with "value semantics" do
		it "exposes the encoded representation" do
			path = Protocol::URL::Path[["", "a", "b/c"]]
			
			expect(path.encoded).to be == "/a/b%2Fc"
			expect(path.to_s).to be == path.encoded
		end
		
		it "compares decoded components" do
			expect(Protocol::URL::Path["/a/%62"]).to be == Protocol::URL::Path["/a/b"]
			expect(Protocol::URL::Path["/a/%62"].hash).to be == Protocol::URL::Path["/a/b"].hash
		end
		
		it "preserves encoded separator boundaries" do
			encoded_separator = Protocol::URL::Path["/a/b%2Fc"]
			structural_separator = Protocol::URL::Path["/a/b/c"]
			
			expect(encoded_separator.components).to be == ["", "a", "b/c"]
			expect(encoded_separator).not.to be == structural_separator
		end
	end
	
	with "path properties" do
		it "distinguishes encoded absolute and relative paths" do
			expect(Protocol::URL::Path["/a"]).to be(:absolute?)
			expect(Protocol::URL::Path["a"]).to be(:relative?)
		end
		
		it "distinguishes component-backed absolute and relative paths" do
			expect(Protocol::URL::Path[["", "a"]]).to be(:absolute?)
			expect(Protocol::URL::Path[["a"]]).to be(:relative?)
		end
		
		it "identifies encoded files and directories" do
			expect(Protocol::URL::Path["/a/b/"]).to be(:directory?)
			expect(Protocol::URL::Path["/a/b"]).not.to be(:directory?)
		end
		
		it "identifies component-backed files and directories" do
			expect(Protocol::URL::Path[["", "a", "b", ""]]).to be(:directory?)
			expect(Protocol::URL::Path[["", "a", "b"]]).not.to be(:directory?)
		end
		
		it "returns the final decoded component as the basename" do
			expect(Protocol::URL::Path["/a/b%2Fc"].basename).to be == "b/c"
		end
		
		it "can omit the final extension from the basename" do
			expect(Protocol::URL::Path["/archive.tar.gz"].basename(extension: false)).to be == "archive.tar"
		end
		
		it "preserves a basename without an extension" do
			expect(Protocol::URL::Path["/README"].basename(extension: false)).to be == "README"
		end
		
		it "preserves dot files and dot segments" do
			expect(Protocol::URL::Path["/.profile"].basename(extension: false)).to be == ".profile"
			expect(Protocol::URL::Path["/.."].basename(extension: false)).to be == ".."
		end
		
		it "can omit an extension from a dot file" do
			expect(Protocol::URL::Path["/.profile.local"].basename(extension: false)).to be == ".profile"
		end
		
		it "returns an empty basename for a directory" do
			expect(Protocol::URL::Path["/a/b/"].basename).to be == ""
		end
		
		it "returns no basename for an empty path" do
			expect(Protocol::URL::Path[""].basename).to be_nil
		end
		
		it "returns an absolute parent path" do
			expect(Protocol::URL::Path["/a/b"].parent).to be == Protocol::URL::Path["/a"]
		end
		
		it "returns a relative parent path" do
			expect(Protocol::URL::Path["a/b"].parent).to be == Protocol::URL::Path["a"]
		end
		
		it "can return a multi-level parent" do
			expect(Protocol::URL::Path["/a/b/c"].parent(2)).to be == Protocol::URL::Path["/a"]
			expect(Protocol::URL::Path["a/b/c"].parent(2)).to be == Protocol::URL::Path["a"]
		end
		
		it "returns itself for a zero-level parent" do
			path = Protocol::URL::Path["/a/b"]
			
			expect(path.parent(0)).to be_equal(path)
		end
		
		it "clamps multi-level parents at the path root" do
			expect(Protocol::URL::Path["/a/b"].parent(10)).to be == Protocol::URL::Path["/"]
			expect(Protocol::URL::Path["a/b"].parent(10)).to be == Protocol::URL::Path[""]
		end
		
		it "rejects an invalid parent level" do
			expect do
				Protocol::URL::Path["/a/b"].parent(-1)
			end.to raise_exception(ArgumentError, message: be == "Path parent level must be a non-negative integer!")
			
			expect do
				Protocol::URL::Path["/a/b"].parent(1.5)
			end.to raise_exception(ArgumentError, message: be == "Path parent level must be a non-negative integer!")
		end
		
		it "preserves encoded component boundaries in the parent" do
			expect(Protocol::URL::Path["/a%2Fb/c"].parent).to be == Protocol::URL::Path["/a%2Fb"]
		end
		
		it "removes a trailing directory component" do
			expect(Protocol::URL::Path["/a/b/"].parent).to be == Protocol::URL::Path["/a/b"]
		end
		
		it "returns the root as the parent of an absolute top-level path" do
			expect(Protocol::URL::Path["/a"].parent).to be == Protocol::URL::Path["/"]
		end
		
		it "does not traverse above the root or empty path" do
			root = Protocol::URL::Path["/"]
			empty = Protocol::URL::Path[""]
			
			expect(root.parent).to be_equal(root)
			expect(empty.parent).to be_equal(empty)
		end
		
		it "identifies an empty path" do
			expect(Protocol::URL::Path[""]).to be(:empty?)
			expect(Protocol::URL::Path["/"]).not.to be(:empty?)
		end
	end
	
	with "#simplify" do
		{
			"simplifies an empty path" => [[], []],
			"preserves the root path" => [["", ""], ["", ""]],
			"preserves a simple absolute path" => [["", "a", "b", "c"], ["", "a", "b", "c"]],
			"preserves a simple relative path" => [["a", "b", "c"], ["a", "b", "c"]],
			"removes a leading current directory" => [[".", "a", "b"], ["a", "b"]],
			"removes an intermediate current directory" => [["a", ".", "b"], ["a", "b"]],
			"preserves a trailing directory marker" => [["a", "b", "."], ["a", "b", ""]],
			"collapses repeated separators" => [["a", "", "b", "", "", "c"], ["a", "b", "c"]],
			"preserves a trailing separator" => [["a", "b", ""], ["a", "b", ""]],
			"resolves a parent directory" => [["a", "b", "..", "c"], ["a", "c"]],
			"resolves multiple parent directories" => [["a", "b", "c", "..", "..", "d"], ["a", "d"]],
			"preserves a trailing directory after a parent" => [["a", "b", ".."], ["a", ""]],
			"resolves a parent at the absolute root" => [["", "a", ".."], ["", ""]],
			"cannot traverse above the absolute root" => [["", "..", "a"], ["", "a"]],
			"preserves a parent at the relative root" => [["..", "a"], ["..", "a"]],
			"preserves multiple parents at the relative root" => [["..", "..", "a"], ["..", "..", "a"]],
			"retains unresolved parent markers" => [["a", "..", "..", "b"], ["..", "b"]],
			"handles a complex path" => [["", "a", "b", ".", "c", "..", "d", "", "e"], ["", "a", "b", "d", "e"]],
			"resolves all dot segments" => [[".", "a", ".", "b", "..", "c", ".", "d", ".."], ["a", "c", ""]],
		}.each do |description, (components, expected)|
			it description do
				path = Protocol::URL::Path[components]
				
				expect(path.simplify.components).to be == expected
			end
		end
		
		it "does not modify the original path" do
			path = Protocol::URL::Path[["a", ".", "b", "..", "c"]]
			
			expect(path.simplify.components).to be == ["a", "c"]
			expect(path.components).to be == ["a", ".", "b", "..", "c"]
		end
		
		it "returns self when already canonical" do
			path = Protocol::URL::Path[["", "a", "b", ""]]
			
			expect(path.simplify).to be_equal(path)
		end
	end
	
	with "#simplify!" do
		it "modifies and returns the path" do
			path = Protocol::URL::Path[["a", ".", "b", "..", "c"]]
			
			expect(path.simplify!).to be_equal(path)
			expect(path.components).to be == ["a", "c"]
		end
		
		it "returns nil when the path is already canonical" do
			path = Protocol::URL::Path[["a", "b"]]
			
			expect(path.simplify!).to be_nil
		end
		
		it "preserves relative parent components" do
			path = Protocol::URL::Path[["a", "..", "..", "b"]]
			
			path.simplify!
			expect(path.components).to be == ["..", "b"]
		end
		
		it "preserves the absolute root and trailing separator" do
			path = Protocol::URL::Path[["", "..", "a", "", "b", "..", ""]]
			
			path.simplify!
			expect(path.components).to be == ["", "a", ""]
		end
	end
	
	with "#join" do
		it "returns the base for an empty relative path" do
			base = Protocol::URL::Path["/foo/bar"]
			
			expect(base.join("")).to be_equal(base)
		end
		
		it "replaces the base with an absolute path" do
			result = Protocol::URL::Path["/base/path"].join("/new/path")
			
			expect(result).to be == Protocol::URL::Path["/new/path"]
		end
		
		it "resolves and simplifies a relative path" do
			result = Protocol::URL::Path["/a/b/c"].join("../d")
			
			expect(result).to be == Protocol::URL::Path["/a/d"]
		end
		
		it "can preserve the final base component" do
			result = Protocol::URL::Path["/a/b/c"].join("d", pop: false)
			
			expect(result).to be == Protocol::URL::Path["/a/b/c/d"]
		end
		
		it "preserves encoded separator boundaries" do
			result = Protocol::URL::Path["/a/b%2Fc"].join("../d")
			
			expect(result).to be == Protocol::URL::Path["/d"]
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
	
	with "#local_path" do
		it "converts simple absolute path" do
			result = Protocol::URL::Path["/documents/report.pdf"].local_path
			expect(result).to be == "/documents/report.pdf"
		end
		
		it "converts simple relative path" do
			result = Protocol::URL::Path["documents/report.pdf"].local_path
			expect(result).to be == "documents/report.pdf"
		end
		
		it "unescapes percent-encoded characters" do
			result = Protocol::URL::Path["/files/My%20Document.txt"].local_path
			expect(result).to be == "/files/My Document.txt"
		end
		
		it "unescapes unicode characters" do
			result = Protocol::URL::Path["/files/%E2%9D%A4%EF%B8%8F.txt"].local_path
			expect(result).to be == "/files/❤️.txt"
		end
		
		it "rejects invalid component encoding" do
			path = Protocol::URL::Path[["\xFF".dup.force_encoding(::Encoding::UTF_8)]]
			
			expect do
				path.local_path
			end.to raise_exception(ArgumentError, message: be == "Path has invalid encoding!")
		end
		
		it "rejects components unavailable in the requested encoding" do
			path = Protocol::URL::Path[["❤️.txt"]]
			
			expect do
				path.local_path(encoding: ::Encoding::US_ASCII)
			end.to raise_exception(ArgumentError, message: be == "Path could not be converted to a local path!")
		end
		
		it "preserves empty path" do
			result = Protocol::URL::Path[""].local_path
			expect(result).to be == ""
		end
		
		it "converts root path" do
			result = Protocol::URL::Path["/"].local_path
			expect(result).to be == "/"
		end
		
		it "handles path with trailing slash" do
			result = Protocol::URL::Path["/documents/folder/"].local_path
			expect(result).to be == "/documents/folder/"
		end
		
		it "preserves parent components for the caller to resolve" do
			result = Protocol::URL::Path["/documents/../private.txt"].local_path
			
			expect(result).to be == "/documents/../private.txt"
		end
		
		with "security: encoded path separators" do
			it "rejects %2F within a component" do
				expect do
					Protocol::URL::Path["/folder/safe%2Fname/file.txt"].local_path
				end.to raise_exception(ArgumentError, message: be =~ /invalid characters/)
			end
			
			it "handles %5C according to the platform" do
				if File::ALT_SEPARATOR
					expect do
						Protocol::URL::Path["/folder/name%5Cfile.txt"].local_path
					end.to raise_exception(ArgumentError, message: be =~ /invalid characters/)
				else
					result = Protocol::URL::Path["/folder/name%5Cfile.txt"].local_path
					expect(result).to be == "/folder/name\\file.txt"
				end
			end
			
			it "rejects multiple encoded separators" do
				expect do
					Protocol::URL::Path["/a%2Fb%2Fc/d.txt"].local_path
				end.to raise_exception(ArgumentError, message: be =~ /invalid characters/)
			end
			
			it "rejects encoded separators after decoding other characters" do
				expect do
					Protocol::URL::Path["/folder/My%20File%2Fname.txt"].local_path
				end.to raise_exception(ArgumentError, message: be =~ /invalid characters/)
			end
			
			it "allows encoded dots (not path traversal when literal)" do
				# %2E is the encoded form of .
				# Two of them (%2E%2E) as literal characters are fine - they're not ".."
				result = Protocol::URL::Path["/folder/%2E%2E/file.txt"].local_path
				expect(result).to be == "/folder/../file.txt"
			end
		end
		
		with "edge cases" do
			it "handles multiple consecutive slashes" do
				# Multiple slashes create empty components, File.join collapses them
				result = Protocol::URL::Path["/a//b///c"].local_path
				expect(result).to be == "/a/b/c"
			end
			
			it "handles special characters in filenames" do
				result = Protocol::URL::Path["/files/name%21%40%23.txt"].local_path
				expect(result).to be == "/files/name!@#.txt"
			end
			
			it "handles mixed encoded and unencoded" do
				result = Protocol::URL::Path["/files/My%20Documents/file.txt"].local_path
				expect(result).to be == "/files/My Documents/file.txt"
			end
		end
	end
end
