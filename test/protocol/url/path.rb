# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "protocol/url/path"

describe Protocol::URL::Path do
	with ".[]" do
		it "returns an existing path" do
			path = Protocol::URL::Path["/a/b"]
			
			expect(Protocol::URL::Path[path]).to be_equal(path)
		end
		
		it "interprets strings as encoded paths" do
			path = Protocol::URL::Path["/a/b%2Fc"]
			
			expect(path.segments).to be == ["", "a", "b%2Fc"]
			expect(path.components).to be == ["", "a", "b/c"]
		end
		
		it "interprets arrays as encoded segments" do
			path = Protocol::URL::Path[["", "a", "b%2Fc"]]
			
			expect(path.encoded).to be == "/a/b%2Fc"
			expect(path.components).to be == ["", "a", "b/c"]
		end
		
		it "rejects structural separators inside encoded segments" do
			expect do
				Protocol::URL::Path[["a/b"]]
			end.to raise_exception(ArgumentError, message: be == "Path contains an invalid encoded segment!")
		end
		
		it "does not retain mutable encoded segments" do
			segment = +"a"
			segments = [segment]
			path = Protocol::URL::Path[segments]
			
			segment.replace("b")
			segments.clear
			
			expect(path.segments).to be == ["a"]
			expect(path.segments.first).to be(:frozen?)
			expect(path.encoded).to be == "a"
		end
		
	end
	
	with ".for" do
		it "escapes decoded components independently" do
			path = Protocol::URL::Path.for(["", "a", "b/c"])
			
			expect(path.segments).to be == ["", "a", "b%2Fc"]
			expect(path.encoded).to be == "/a/b%2Fc"
		end
		
		it "supports a custom encoding" do
			encoding = Object.new
			encoding.define_singleton_method(:escape){|component| "x#{component}"}
			
			expect(Protocol::URL::Path.for(["a", "b"], encoding: encoding).encoded).to be == "xa/xb"
		end
		
		it "rejects an encoding which produces a separator" do
			encoding = Object.new
			encoding.define_singleton_method(:escape){|component| component + "/invalid"}
			
			expect do
				Protocol::URL::Path.for(["a"], encoding: encoding)
			end.to raise_exception(ArgumentError, message: be == "Path encoding produced an invalid segment!")
		end
	end
	
	with ".new" do
		it "constructs an empty path without a representation" do
			path = Protocol::URL::Path.new(nil)
			
			expect(path).to be(:empty?)
			expect(path.encoded).to be == ""
		end
	end
	
	with "#freeze" do
		it "materializes and freezes both lossless representations" do
			path = Protocol::URL::Path["/a/b"]
			
			expect(path.freeze).to be_equal(path)
			expect(path).to be(:frozen?)
			expect(path.encoded).to be(:frozen?)
			expect(path.segments).to be(:frozen?)
			expect(path.freeze).to be_equal(path)
		end
		
		it "freezes paths constructed from segments" do
			path = Protocol::URL::Path[["", "a", "b%2Fc"]]
			
			expect(path.freeze).to be_equal(path)
			expect(path.encoded).to be == "/a/b%2Fc"
			expect(path.segments).to be == ["", "a", "b%2Fc"]
			expect(path.components).to be == ["", "a", "b/c"]
		end
	end
	
	with "value semantics" do
		it "exposes the encoded representation" do
			path = Protocol::URL::Path[["", "a", "b%2Fc"]]
			
			expect(path.encoded).to be == "/a/b%2Fc"
			expect(path.to_s).to be == path.encoded
		end
		
		it "compares exact encoded representations" do
			encoded = Protocol::URL::Path["/a/%62"]
			literal = Protocol::URL::Path["/a/b"]
			
			expect(encoded).not.to be == literal
			expect(encoded).not.to be(:eql?, literal)
			expect(encoded <=> literal).not.to be == 0
			expect(encoded.hash).to be == Protocol::URL::Path["/a/%62"].hash
		end
		
		it "preserves encoded separator boundaries" do
			encoded_separator = Protocol::URL::Path["/a/b%2Fc"]
			structural_separator = Protocol::URL::Path["/a/b/c"]
			
			expect(encoded_separator.components).to be == ["", "a", "b/c"]
			expect(encoded_separator).not.to be == structural_separator
		end
		
		it "decodes components on each call using the requested encoding" do
			path = Protocol::URL::Path["a"]
			first = Object.new
			first.define_singleton_method(:unescape){|segment| "first:#{segment}"}
			second = Object.new
			second.define_singleton_method(:unescape){|segment| "second:#{segment}"}
			
			expect(path.components(first)).to be == ["first:a"]
			expect(path.components(second)).to be == ["second:a"]
			expect(path.components(first)).not.to be_equal(path.components(first))
		end
	end
	
	with "path properties" do
		it "distinguishes encoded absolute and relative paths" do
			expect(Protocol::URL::Path["/a"]).to be(:absolute?)
			expect(Protocol::URL::Path["a"]).to be(:relative?)
		end
		
		it "distinguishes segment-backed absolute and relative paths" do
			expect(Protocol::URL::Path[["", "a"]]).to be(:absolute?)
			expect(Protocol::URL::Path[["a"]]).to be(:relative?)
		end
		
		it "identifies encoded files and directories" do
			expect(Protocol::URL::Path["/a/b/"]).to be(:directory?)
			expect(Protocol::URL::Path["/a/b"]).not.to be(:directory?)
		end
		
		it "identifies segment-backed files and directories" do
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
		
		it "preserves reserved escapes in the parent" do
			expect(Protocol::URL::Path["a%3Ab/c"].parent.encoded).to be == "a%3Ab"
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
			"preserves repeated separators" => [["a", "", "b", "", "", "c"], ["a", "", "b", "", "", "c"]],
			"preserves a trailing separator" => [["a", "b", ""], ["a", "b", ""]],
			"resolves a parent directory" => [["a", "b", "..", "c"], ["a", "c"]],
			"resolves multiple parent directories" => [["a", "b", "c", "..", "..", "d"], ["a", "d"]],
			"preserves a trailing directory after a parent" => [["a", "b", ".."], ["a", ""]],
			"resolves a parent at the absolute root" => [["", "a", ".."], ["", ""]],
			"cannot traverse above the absolute root" => [["", "..", "a"], ["", "a"]],
			"preserves a parent at the relative root" => [["..", "a"], ["..", "a"]],
			"preserves multiple parents at the relative root" => [["..", "..", "a"], ["..", "..", "a"]],
			"retains unresolved parent markers" => [["a", "..", "..", "b"], ["..", "b"]],
			"handles a complex path" => [["", "a", "b", ".", "c", "..", "d", "", "e"], ["", "a", "b", "d", "", "e"]],
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
		
		it "preserves reserved escapes in retained segments" do
			path = Protocol::URL::Path["a%3Ab/./c"]
			
			expect(path.simplify.encoded).to be == "a%3Ab/c"
		end
		
		it "simplifies percent-encoded dot segments" do
			path = Protocol::URL::Path["/a/%2e/b/.%2E/c"]
			
			expect(path.simplify.encoded).to be == "/a/c"
		end
		
		it "resolves a parent following an empty segment" do
			path = Protocol::URL::Path["/a//../b"]
			
			expect(path.simplify.encoded).to be == "/a/b"
		end
	end
	
	with "#normalize" do
		it "decodes percent-encoded unreserved characters" do
			path = Protocol::URL::Path["/%41%7a%30%2d%2e%5f%7e"]
			
			expect(path.normalize.encoded).to be == "/Az0-._~"
		end
		
		it "uses uppercase hexadecimal digits for retained percent escapes" do
			path = Protocol::URL::Path["/a%2fb%3fc%ff"]
			
			expect(path.normalize.encoded).to be == "/a%2Fb%3Fc%FF"
		end
		
		it "preserves literal path segment delimiters" do
			path = Protocol::URL::Path["/!$&'()*+,;=:@"]
			
			expect(path.normalize).to be_equal(path)
		end
		
		it "preserves the distinction between encoded and literal reserved characters" do
			path = Protocol::URL::Path["/a%3Ab:a%2Fb"]
			
			expect(path.normalize).to be_equal(path)
		end
		
		it "percent encodes characters outside the path segment grammar" do
			path = Protocol::URL::Path["/hello world?[x]#"]
			
			expect(path.normalize.encoded).to be == "/hello%20world%3F%5Bx%5D%23"
		end
		
		it "percent encodes literal unicode characters" do
			path = Protocol::URL::Path["/❤️"]
			
			expect(path.normalize.encoded).to be == "/%E2%9D%A4%EF%B8%8F"
		end
		
		it "preserves path structure" do
			path = Protocol::URL::Path["//a/%2e%2e/%77elcome"]
			
			expect(path.normalize.encoded).to be == "//a/../welcome"
		end
		
		it "returns itself when already normalized" do
			path = Protocol::URL::Path["/welcome/a:b/%2F"]
			
			expect(path.normalize).to be_equal(path)
		end
		
		it "rejects literal NUL" do
			path = Protocol::URL::Path["/a\0b"]
			
			expect do
				path.normalize
			end.to raise_exception(ArgumentError, message: be == "Path segment contains NUL!")
		end
		
		it "rejects percent-encoded NUL" do
			path = Protocol::URL::Path["/a%00b"]
			
			expect do
				path.normalize
			end.to raise_exception(ArgumentError, message: be == "Path segment contains NUL!")
		end
		
		it "rejects malformed percent encoding" do
			["/a%", "/a%0", "/a%gg"].each do |encoded|
				expect do
					Protocol::URL::Path[encoded].normalize
				end.to raise_exception(ArgumentError, message: be == "String contains malformed percent encoding!")
			end
		end
		
		it "rejects invalid string encoding" do
			path = Protocol::URL::Path["/a\xFF".dup.force_encoding(::Encoding::UTF_8)]
			
			expect do
				path.normalize
			end.to raise_exception(ArgumentError, message: be == "Path segment has invalid encoding!")
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
			expect(path.components).to be == ["", "a", "", ""]
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
		
		it "preserves reserved escapes in retained segments" do
			result = Protocol::URL::Path["a%3Ab/c"].join("d")
			
			expect(result.encoded).to be == "a%3Ab/d"
		end
		
		it "preserves encoded semicolons in retained segments" do
			result = Protocol::URL::Path["g%3Bx/c"].join("d")
			
			expect(result.encoded).to be == "g%3Bx/d"
		end
		
		it "treats encoded dot segments as traversal" do
			result = Protocol::URL::Path["/a/b"].join("%2E%2E/d")
			
			expect(result.encoded).to be == "/d"
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
		
		it "compares encoded segments without normalizing reserved escapes" do
			expect(Protocol::URL::Path.relative("/a%3Ab/d", "/a:b/c")).to be == "../a%3Ab/d"
		end
	end
	
	with "#local_path" do
		let(:root) {File.expand_path("public", Dir.pwd)}
		
		it "requires a filesystem root" do
			expect do
				Protocol::URL::Path["/documents/report.pdf"].local_path
			end.to raise_exception(ArgumentError)
		end
		
		it "resolves absolute and relative URL paths beneath the root" do
			expected = File.join(root, "documents", "report.pdf")
			
			expect(Protocol::URL::Path["/documents/report.pdf"].local_path(root)).to be == expected
			expect(Protocol::URL::Path["documents/report.pdf"].local_path(root)).to be == expected
		end
		
		it "maps empty URL segments to the same local filesystem path" do
			expected = File.join(root, "documents", "report.pdf")
			
			expect(Protocol::URL::Path["/documents//report.pdf"].local_path(root)).to be == expected
		end
		
		it "unescapes percent-encoded and Unicode characters" do
			expect(Protocol::URL::Path["/files/My%20Document.txt"].local_path(root)).to be == File.join(root, "files", "My Document.txt")
			expect(Protocol::URL::Path["/files/%E2%9D%A4%EF%B8%8F.txt"].local_path(root)).to be == File.join(root, "files", "❤️.txt")
		end
		
		it "rejects invalid component encoding" do
			path = Protocol::URL::Path.for(["\xFF".dup.force_encoding(::Encoding::UTF_8)])
			
			expect do
				path.local_path(root)
			end.to raise_exception(ArgumentError, message: be == "Path component has invalid encoding!")
		end
		
		it "resolves empty and root paths to the filesystem root" do
			expect(Protocol::URL::Path[""].local_path(root)).to be == root
			expect(Protocol::URL::Path["/"].local_path(root)).to be == root
		end
		
		it "normalizes trailing separators on roots and URL paths" do
			path = Protocol::URL::Path["/documents/folder/"]
			expected = File.join(root, "documents", "folder")
			
			expect(path.local_path(root + File::SEPARATOR)).to be == expected
		end
		
		it "resolves parent components which remain within the root" do
			path = Protocol::URL::Path["/documents/../private.txt"]
			
			expect(path.local_path(root)).to be == File.join(root, "private.txt")
		end
		
		it "rejects literal or percent-encoded traversal beyond the root" do
			["../etc/passwd", "/../../etc/passwd", "/%2E%2E/%2E%2E/etc/passwd"].each do |encoded|
				expect do
					Protocol::URL::Path[encoded].local_path(root)
				end.to raise_exception(ArgumentError, message: be == "Path escapes the specified root!")
			end
		end
		
		it "does not confuse roots with sibling path prefixes" do
			path = Protocol::URL::Path["../publicity/file.txt"]
			
			expect do
				path.local_path(root)
			end.to raise_exception(ArgumentError, message: be == "Path escapes the specified root!")
		end
		
		it "expands relative filesystem roots" do
			relative_root = File.join("tmp", "public")
			
			expect(Protocol::URL::Path["file.txt"].local_path(relative_root)).to be == File.expand_path(File.join(relative_root, "file.txt"))
		end
		
		with "security: encoded path separators" do
			it "rejects encoded NUL characters" do
				expect do
					Protocol::URL::Path["/folder/file%00.txt"].local_path(root)
				end.to raise_exception(ArgumentError, message: be == "Path component contains invalid characters!")
			end
			
			it "rejects %2F within a component" do
				expect do
					Protocol::URL::Path["/folder/safe%2Fname/file.txt"].local_path(root)
				end.to raise_exception(ArgumentError, message: be =~ /invalid characters/)
			end
			
			it "handles %5C according to the platform" do
				if File::ALT_SEPARATOR
					expect do
						Protocol::URL::Path["/folder/name%5Cfile.txt"].local_path(root)
					end.to raise_exception(ArgumentError, message: be =~ /invalid characters/)
				else
					result = Protocol::URL::Path["/folder/name%5Cfile.txt"].local_path(root)
					expect(result).to be == File.join(root, "folder", "name\\file.txt")
				end
			end
			
			it "rejects multiple encoded separators" do
				expect do
					Protocol::URL::Path["/a%2Fb%2Fc/d.txt"].local_path(root)
				end.to raise_exception(ArgumentError, message: be =~ /invalid characters/)
			end
			
			it "rejects encoded separators after decoding other characters" do
				expect do
					Protocol::URL::Path["/folder/My%20File%2Fname.txt"].local_path(root)
				end.to raise_exception(ArgumentError, message: be =~ /invalid characters/)
			end
		end
		
		with "edge cases" do
			it "collapses repeated leading and intermediate separators beneath the root" do
				expect(Protocol::URL::Path["//a//b///c"].local_path(root)).to be == File.join(root, "a", "b", "c")
			end
			
			it "preserves tilde-prefixed components literally" do
				expect(Protocol::URL::Path["~/file.txt"].local_path(root)).to be == File.join(root, "~", "file.txt")
				expect(Protocol::URL::Path["~root/file.txt"].local_path(root)).to be == File.join(root, "~root", "file.txt")
			end
			
			it "handles special and mixed encoded characters" do
				expect(Protocol::URL::Path["/files/name%21%40%23.txt"].local_path(root)).to be == File.join(root, "files", "name!@#.txt")
				expect(Protocol::URL::Path["/files/My%20Documents/file.txt"].local_path(root)).to be == File.join(root, "files", "My Documents", "file.txt")
			end
		end
	end
end
