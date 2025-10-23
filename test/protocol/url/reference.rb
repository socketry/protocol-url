# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require "protocol/url/reference"

describe Protocol::URL::Reference do
	let(:reference) {subject.new}
	
	with "#base" do
		let(:reference) {subject.new("/foo/bar", "foo=bar", "baz", {x: 10})}
		
		it "returns reference with only the path" do
			expect(reference.base).to have_attributes(
				path: be == reference.path,
				parameters: be_nil,
				fragment: be_nil,
			)
		end
	end
	
	with "#+" do
		let(:absolute) {subject["/foo/bar"]}
		let(:relative) {subject["foo/bar"]}
		let(:up) {subject["../baz"]}
		
		it "can add a relative path" do
			expect(reference + relative).to be == absolute
		end
		
		it "can add an absolute path" do
			expect(reference + absolute).to be == absolute
		end
		
		it "can add an absolute path" do
			expect(relative + absolute).to be == absolute
		end
		
		it "can remove relative parts" do
			expect(absolute + up).to be == subject["/baz"]
		end
	end
	
	with "#freeze" do
		it "can freeze reference" do
			expect(reference.freeze).to be_equal(reference)
			expect(reference).to be(:frozen?)
		end
	end
	
	with ".[]" do
		it "raises error for invalid input type" do
			expect do
				subject[123]
			end.to raise_exception(ArgumentError, message: be =~ /Cannot coerce/)
		end
		
		it "returns nil for nil input" do
			expect(subject[nil]).to be_nil
		end
		
		it "accepts Relative objects" do
			relative = Protocol::URL::Relative.new("/path", "q=test", "frag")
			ref = subject[relative]
			expect(ref.path).to be == "/path"
			expect(ref.query).to be == "q=test"
			expect(ref.fragment).to be == "frag"
		end
		
		it "unescapes encoded paths from Relative objects" do
			# Relative stores encoded values, Reference should store unescaped
			relative = Protocol::URL::Relative.new("/path%20with%20spaces", "q=test", "frag%20ment")
			ref = subject[relative]
			
			# Reference should unescape the path and fragment
			expect(ref.path).to be == "/path with spaces"
			expect(ref.fragment).to be == "frag ment"
			
			# When converted back to string, should be re-encoded
			expect(ref.to_s).to be == "/path%20with%20spaces?q=test#frag%20ment"
		end
		
		it "handles unicode in Relative objects" do
			# Relative stores encoded unicode
			relative = Protocol::URL::Relative.new("/I/%E2%9D%A4%EF%B8%8F/UNICODE", nil, nil)
			ref = subject[relative]
			
			# Reference should unescape to unicode
			expect(ref.path).to be == "/I/❤️/UNICODE"
			
			# When converted back to string, should be re-encoded
			expect(ref.to_s).to be == "/I/%E2%9D%A4%EF%B8%8F/UNICODE"
		end
	end
	
	with "#with" do
		it "can nest paths" do
			reference = subject.new("/foo")
			expect(reference.path).to be == "/foo"
			
			nested_resource = reference.with(path: "bar")
			expect(nested_resource.path).to be == "/foo/bar"
		end
		
		it "can update path" do
			copy = reference.with(path: "foo/bar.html")
			expect(copy.path).to be == "/foo/bar.html"
		end
		
		it "can append path components" do
			copy = reference.with(path: "foo/").with(path: "bar/")
			
			expect(copy.path).to be == "/foo/bar/"
		end
		
		it "can append empty path components" do
			copy = reference.with(path: "")
			
			expect(copy.path).to be == reference.path
		end
		
		it "can append parameters" do
			copy = reference.with(parameters: {x: 10})
			
			expect(copy.parameters).to be == {x: 10}
		end
		
		it "can merge parameters" do
			copy = reference.with(parameters: {x: 10}).with(parameters: {y: 20})
			
			expect(copy.parameters).to be == {x: 10, y: 20}
		end
		
		it "can copy parameters" do
			copy = reference.with(parameters: {x: 10}).with(path: "foo")
			
			expect(copy.parameters).to be == {x: 10}
			expect(copy.path).to be == "/foo"
		end
		
		it "can replace path with absolute path" do
			copy = reference.with(path: "foo").with(path: "/bar")
			
			expect(copy.path).to be == "/bar"
		end
		
		it "can replace path with relative path" do
			copy = reference.with(path: "foo").with(path: "../../bar")
			
			expect(copy.path).to be == "/bar"
		end
		
		with "#query" do
			let(:reference) {subject.new("foo/bar/baz.html", "x=10", nil, nil)}
			
			it "can replace query" do
				copy = reference.with(parameters: nil, merge: false)
				
				expect(copy.parameters).to be_nil
				expect(copy.query).to be_nil
			end
			
			it "keeps existing query when merge: false with no parameters" do
				copy = reference.with(fragment: "new-fragment", merge: false)
				
				# Original had no parameters:
				expect(copy.parameters).to be_nil
				
				# Query should be preserved:
				expect(copy.query).to be == "x=10"
				
				# Fragment should be updated:
				expect(copy.fragment).to be == "new-fragment"
			end
			
			it "replaces query when explicitly specified with merge: true" do
				# When merge: true (default), explicitly passing query: replaces it
				copy = reference.with(query: "a=1&b=2")
				
				expect(copy.query).to be == "a=1&b=2"
				expect(copy.to_s).to be == "foo/bar/baz.html?a=1&b=2"
			end
			
			it "keeps existing query when not specified with merge: true" do
				# When merge: true (default), not passing query: keeps the existing one
				copy = reference.with(fragment: "new-fragment")
				
				expect(copy.query).to be == "x=10"
				expect(copy.fragment).to be == "new-fragment"
				expect(copy.to_s).to be == "foo/bar/baz.html?x=10#new-fragment"
			end
			
			it "clears query when nil is explicitly passed with merge: true" do
				# Explicitly passing query: nil clears it
				copy = reference.with(query: nil)
				
				expect(copy.query).to be_nil
				expect(copy.to_s).to be == "foo/bar/baz.html"
			end
		end
		
		with "parameters and query" do
			let(:reference) {subject.new("foo/bar/baz.html", "x=10", nil, {y: 20, z: 30})}
			
			it "keeps existing parameters and query when merge: false with no new parameters" do
				copy = reference.with(fragment: "new-fragment", merge: false)
				
				# Original parameters preserved:
				expect(copy.parameters).to be == {y: 20, z: 30}
				
				# Query should be preserved:
				expect(copy.query).to be == "x=10"
				
				# Fragment should be updated:
				expect(copy.fragment).to be == "new-fragment"
			end
			
			it "clears query when merge: false with new parameters" do
				# When merge: false and parameters are provided, query is cleared
				copy = reference.with(parameters: {a: 1}, merge: false)
				
				# Parameters replaced:
				expect(copy.parameters).to be == {a: 1}
				
				# Query cleared:
				expect(copy.query).to be_nil
				expect(copy.to_s).to be == "foo/bar/baz.html?a=1"
			end
			
			it "can keep query when merge: false by explicitly passing it" do
				# You can override the query clearing by explicitly passing query:
				copy = reference.with(parameters: {a: 1}, query: "x=10", merge: false)
				
				# Parameters replaced:
				expect(copy.parameters).to be == {a: 1}
				
				# Query kept because explicitly specified:
				expect(copy.query).to be == "x=10"
				expect(copy.to_s).to be == "foo/bar/baz.html?x=10&a=1"
			end
		end
		
		with "relative path" do
			let(:reference) {subject.new("foo/bar/baz.html", nil, nil, nil)}
			
			it "can compute new relative path" do
				copy = reference.with(path: "../index.html", pop: true)
				
				expect(copy.path).to be == "foo/index.html"
			end
			
			it "can compute relative path with more uplevels" do
				copy = reference.with(path: "../../../index.html", pop: true)
				
				expect(copy.path).to be == "../index.html"
			end
		end
	end
	
	with "empty query string" do
		let(:reference) {subject.new("/", "", nil, {})}
		
		it "it should not append query string" do
			expect(reference.to_s).not.to be(:include?, "?")
		end
		
		it "can add a relative path" do
			result = reference + subject["foo/bar"]
			
			expect(result.to_s).to be == "/foo/bar"
		end
	end
	
	with "empty fragment" do
		let(:reference) {subject.new("/", nil, "", nil)}
		
		it "it should not append query string" do
			expect(reference.to_s).not.to be(:include?, "#")
		end
	end
	
	describe Protocol::URL::Reference.parse("path%20with%20spaces/image.jpg") do
		it "preserves encoded whitespace" do
			expect(subject.to_s).to be == "path%20with%20spaces/image.jpg"
		end
	end
	
	with "invalid input" do
		it "accepts properly encoded input" do
			# This should work - it's properly encoded
			ref = Protocol::URL::Reference.parse("path%20with%20spaces")
			expect(ref.to_s).to be == "path%20with%20spaces"
		end
		
		it "rejects strings with unencoded whitespace" do
			expect do
				Protocol::URL::Reference.parse("path with spaces")
			end.to raise_exception(ArgumentError, message: be =~ /Invalid URL.*whitespace/)
		end
		
		it "rejects strings with control characters" do
			expect do
				Protocol::URL::Reference.parse("path\r\n")
			end.to raise_exception(ArgumentError, message: be =~ /Invalid URL.*control characters/)
		end
	end
	
	describe Protocol::URL::Reference.parse("path", array: [1, 2, 3]) do
		it "encodes array" do
			expect(subject.to_s).to be == "path?array[]=1&array[]=2&array[]=3"
		end
	end
	
	describe Protocol::URL::Reference.parse("path_with_underscores/image.jpg") do
		it "doesn't touch underscores" do
			expect(subject.to_s).to be == "path_with_underscores/image.jpg"
		end
	end
	
	describe Protocol::URL::Reference.parse("index", "my name" => "Bob Dole") do
		it "encodes query" do
			expect(subject.to_s).to be == "index?my%20name=Bob%20Dole"
		end
	end
	
	describe Protocol::URL::Reference.parse("index#All%20Your%20Base") do
		it "encodes fragment" do
			expect(subject.to_s).to be == "index\#All%20Your%20Base"
		end
	end
	
	describe Protocol::URL::Reference.new("I/❤️/UNICODE", nil, nil, {face: "😀"}) do
		it "encodes unicode" do
			expect(subject.to_s).to be == "I/%E2%9D%A4%EF%B8%8F/UNICODE?face=%F0%9F%98%80"
		end
	end
	
	with "encoding contract" do
		with "parse() with encoded input" do
			it "unescapes path and fragment, keeps query as-is" do
				ref = Protocol::URL::Reference.parse("path%20with%20spaces?foo=bar&baz=qux#frag%20ment")
				
				# Unescaped internally:
				expect(ref.path).to be == "path with spaces"
				expect(ref.fragment).to be == "frag ment"
				
				# Query kept as-is:
				expect(ref.query).to be == "foo=bar&baz=qux"
				
				# Re-encoded on output:
				expect(ref.to_s).to be == "path%20with%20spaces?foo=bar&baz=qux#frag%20ment"
			end
		end
		
		with "new() with unescaped input" do
			it "accepts unescaped path and fragment" do
				ref = Protocol::URL::Reference.new("path with spaces", nil, "frag ment")
				
				# Stored unescaped:
				expect(ref.path).to be == "path with spaces"
				expect(ref.fragment).to be == "frag ment"
				
				# Encoded on output:
				expect(ref.to_s).to be == "path%20with%20spaces#frag%20ment"
			end
			
			it "accepts pre-formatted query string" do
				ref = Protocol::URL::Reference.new("path", "foo=bar&baz=qux")
				
				# Query stored as-is:
				expect(ref.query).to be == "foo=bar&baz=qux"
				
				# Passed through on output:
				expect(ref.to_s).to be == "path?foo=bar&baz=qux"
			end
			
			it "safely encodes parameters" do
				ref = Protocol::URL::Reference.new("path", nil, nil, {name: "Bob Dole", city: "New York"})
				
				# Parameters stored as hash:
				expect(ref.parameters).to be == {name: "Bob Dole", city: "New York"}
				
				# Encoded on output:
				result = ref.to_s
				expect(result).to be(:start_with?, "path?")
				expect(result).to be(:include?, "name=Bob%20Dole")
				expect(result).to be(:include?, "city=New%20York")
			end
			
			it "handles unicode in path" do
				ref = Protocol::URL::Reference.new("I/❤️/UNICODE")
				
				# Stored unescaped:
				expect(ref.path).to be == "I/❤️/UNICODE"
				
				# Encoded on output:
				expect(ref.to_s).to be == "I/%E2%9D%A4%EF%B8%8F/UNICODE"
			end
		end
		
		with "query string handling" do
			it "treats query as already-formatted with structural characters" do
				# Query strings contain = and & which are NOT encoded
				ref = Protocol::URL::Reference.new("path", "key=value&key2=value2")
				expect(ref.to_s).to be == "path?key=value&key2=value2"
			end
			
			it "does not validate query string format" do
				# This is a limitation - invalid query strings are passed through
				# Users should use parameters for safety
				ref = Protocol::URL::Reference.new("path", "not a valid query")
				expect(ref.query).to be == "not a valid query"
				expect(ref.to_s).to be == "path?not a valid query"
			end
		end
		
		with "path encoding scenarios" do
			it "handles unescaped spaces in new()" do
				# new() expects raw unescaped values
				ref = Protocol::URL::Reference.new("path with spaces")
				expect(ref.path).to be == "path with spaces"
				expect(ref.to_s).to be == "path%20with%20spaces"
			end
			
			it "double-encodes if you pass encoded values to new()" do
				# This is wrong usage, but demonstrates the behavior
				ref = Protocol::URL::Reference.new("path%20with%20spaces")
				
				# Stored as-is (treating %20 as literal characters):
				expect(ref.path).to be == "path%20with%20spaces"
				
				# Gets double-encoded on output:
				expect(ref.to_s).to be == "path%2520with%2520spaces"
			end
			
			it "handles unicode correctly in new()" do
				# Unicode is stored raw and encoded on output
				ref = Protocol::URL::Reference.new("I/❤️/UNICODE")
				expect(ref.path).to be == "I/❤️/UNICODE"
				expect(ref.to_s).to be == "I/%E2%9D%A4%EF%B8%8F/UNICODE"
			end
			
			it "use parse() for already-encoded input" do
				# parse() is the correct method for encoded strings
				ref = Protocol::URL::Reference.parse("path%20with%20spaces")
				expect(ref.path).to be == "path with spaces"
				expect(ref.to_s).to be == "path%20with%20spaces"
			end
		end
		
		with "validation" do
			it "new() does not validate inputs" do
				# new() accepts anything - caller is responsible for valid input
				# It doesn't reject invalid characters, though they will be encoded on output
				ref = Protocol::URL::Reference.new("any\r\nvalue", "any query", "any\tfragment")
				
				# Values are stored as-is:
				expect(ref.path).to be == "any\r\nvalue"
				expect(ref.query).to be == "any query"
				expect(ref.fragment).to be == "any\tfragment"
				
				# Control characters in path/fragment get encoded, but spaces in query are passed through:
				output = ref.to_s
				expect(output).to be(:include?, "any query")  # Query passed through
				expect(output).to be(:include?, "%0D%0A")     # Path control chars encoded
				expect(output).to be(:include?, "%09")        # Fragment control chars encoded
			end
			
			it "parse() validates and rejects invalid input" do
				# parse() enforces RFC 3986 validation
				expect do
					Protocol::URL::Reference.parse("path with spaces")
				end.to raise_exception(ArgumentError, message: be =~ /Invalid URL.*whitespace/)
				
				expect do
					Protocol::URL::Reference.parse("path\r\n")
				end.to raise_exception(ArgumentError, message: be =~ /Invalid URL.*control characters/)
			end
		end
	end
	
	describe Protocol::URL::Reference.parse("foo?bar=10&baz=20", yes: "no") do
		it "can use existing query parameters" do
			expect(subject.to_s).to be == "foo?bar=10&baz=20&yes=no"
		end
	end
	
	describe Protocol::URL::Reference.parse("foo#frag") do
		it "can use existing fragment" do
			expect(subject.fragment).to be == "frag"
			expect(subject.to_s).to be == "foo#frag"
		end
	end
	
	with "#parse_query!" do
		it "parses query string into parameters" do
			reference = subject.parse("/path?foo=bar&baz=qux")
			
			expect(reference.query).to be == "foo=bar&baz=qux"
			expect(reference.parameters).to be_nil
			
			result = reference.parse_query!
			
			expect(result).to be == {"foo" => "bar", "baz" => "qux"}
			expect(reference.query).to be_nil
			expect(reference.parameters).to be == {"foo" => "bar", "baz" => "qux"}
		end
		
		it "merges parsed query with existing parameters" do
			reference = subject.parse("/path?foo=bar&baz=qux", {x: 10, y: 20})
			
			expect(reference.query).to be == "foo=bar&baz=qux"
			expect(reference.parameters).to be == {x: 10, y: 20}
			
			result = reference.parse_query!
			
			expect(result).to be == {x: 10, y: 20, "foo" => "bar", "baz" => "qux"}
			expect(reference.query).to be_nil
			expect(reference.parameters).to be == {x: 10, y: 20, "foo" => "bar", "baz" => "qux"}
		end
		
		it "handles empty query string" do
			reference = subject.parse("/path", {x: 10})
			
			expect(reference.query).to be_nil
			expect(reference.parameters).to be == {x: 10}
			
			result = reference.parse_query!
			
			expect(result).to be == {x: 10}
			expect(reference.query).to be_nil
			expect(reference.parameters).to be == {x: 10}
		end
		
		it "handles no existing parameters" do
			reference = subject.parse("/path?foo=bar")
			
			expect(reference.query).to be == "foo=bar"
			expect(reference.parameters).to be_nil
			
			result = reference.parse_query!
			
			expect(result).to be == {"foo" => "bar"}
			expect(reference.parameters).to be == {"foo" => "bar"}
		end
		
		it "updates to_s output after parsing" do
			reference = subject.parse("/path?foo=bar&baz=qux")
			expect(reference.to_s).to be == "/path?foo=bar&baz=qux"
			
			reference.parse_query!
			# Parameters are now in a hash, so order may differ
			result = reference.to_s
			expect(result).to be(:include?, "foo=bar")
			expect(result).to be(:include?, "baz=qux")
			expect(result).to be(:start_with?, "/path?")
		end
	end
	
	with "#query?" do
		it "returns false for nil query" do
			reference = subject.new("/path", nil, nil, nil)
			expect(reference.query?).to be == nil
		end
		
		it "returns false for empty query" do
			reference = subject.new("/path", "", nil, nil)
			expect(reference.query?).to be == false
		end
		
		it "returns true for non-empty query" do
			reference = subject.new("/path", "foo=bar", nil, nil)
			expect(reference.query?).to be == true
		end
	end
	
	with "#fragment?" do
		it "returns false for nil fragment" do
			reference = subject.new("/path", nil, nil, nil)
			expect(reference.fragment?).to be == nil
		end
		
		it "returns false for empty fragment" do
			reference = subject.new("/path", nil, "", nil)
			expect(reference.fragment?).to be == false
		end
		
		it "returns true for non-empty fragment" do
			reference = subject.new("/path", nil, "section", nil)
			expect(reference.fragment?).to be == true
		end
	end
	
	with "fragment with encoded # character" do
		it "can parse fragment containing %23 (encoded #)" do
			# Fragment contains a literal # character encoded as %23
			reference = subject.parse("/path#section%23subsection")
			# Reference stores unescaped values, so %23 becomes #
			expect(reference.fragment).to be == "section#subsection"
		end
		
		it "can create reference with fragment containing #" do
			# Creating directly with unescaped # in fragment
			reference = subject.new("/path", nil, "section#subsection", nil)
			expect(reference.fragment).to be == "section#subsection"
			# When serialized, # must be encoded as %23
			expect(reference.to_s).to be == "/path#section%23subsection"
		end
		
		it "round-trips fragment with # correctly" do
			original = "/path#section%23subsection"
			reference = subject.parse(original)
			expect(reference.to_s).to be == original
		end
	end
	
	with "multiple ? characters in query string" do
		it "can parse query with multiple ? characters" do
			# Query contains literal ? characters
			reference = subject.parse("/path?query?extra")
			# All ? after the first are part of the query value
			expect(reference.query).to be == "query?extra"
		end
		
		it "preserves multiple ? in query string" do
			reference = subject.new("/path", "foo=bar?baz", nil, nil)
			expect(reference.query).to be == "foo=bar?baz"
			expect(reference.to_s).to be == "/path?foo=bar?baz"
		end
		
		it "round-trips query with ? correctly" do
			original = "/path?query?extra"
			reference = subject.parse(original)
			expect(reference.to_s).to be == original
		end
	end
end
