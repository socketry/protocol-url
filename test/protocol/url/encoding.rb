# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/url/encoding"

describe Protocol::URL::Encoding do
	describe ".escape" do
		it "escapes special characters" do
			expect(Protocol::URL::Encoding.escape("hello world!")).to be == "hello%20world%21"
		end
		
		it "handles unicode characters" do
			expect(Protocol::URL::Encoding.escape("café")).to be == "caf%C3%A9"
		end
	end
	
	describe ".unescape" do
		it "unescapes percent-encoded strings" do
			expect(Protocol::URL::Encoding.unescape("hello%20world%21")).to be == "hello world!"
		end
		
		it "handles unicode characters" do
			expect(Protocol::URL::Encoding.unescape("caf%C3%A9")).to be == "café"
		end
		
		it "unescapes path separators" do
			expect(Protocol::URL::Encoding.unescape("safe%2Fname")).to be == "safe/name"
			expect(Protocol::URL::Encoding.unescape("name%5Cfile")).to be == "name\\file"
		end
	end
	
	describe ".unescape_path" do
		it "unescapes percent-encoded strings" do
			expect(Protocol::URL::Encoding.unescape_path("hello%20world%21")).to be == "hello world!"
		end
		
		it "handles unicode characters" do
			expect(Protocol::URL::Encoding.unescape_path("caf%C3%A9")).to be == "café"
		end
		
		it "preserves encoded forward slashes" do
			expect(Protocol::URL::Encoding.unescape_path("safe%2Fname")).to be == "safe%2Fname"
		end
		
		it "preserves encoded backslashes" do
			expect(Protocol::URL::Encoding.unescape_path("name%5Cfile")).to be == "name%5Cfile"
		end
		
		it "preserves encoded separators while unescaping other characters" do
			expect(Protocol::URL::Encoding.unescape_path("My%20File%2Fname")).to be == "My File%2Fname"
			expect(Protocol::URL::Encoding.unescape_path("folder%5Cname%20with%20spaces")).to be == "folder%5Cname with spaces"
		end
		
		it "handles mixed case encoding for separators" do
			expect(Protocol::URL::Encoding.unescape_path("file%2fname")).to be == "file%2fname"
			expect(Protocol::URL::Encoding.unescape_path("file%2Fname")).to be == "file%2Fname"
			expect(Protocol::URL::Encoding.unescape_path("file%5cname")).to be == "file%5cname"
			expect(Protocol::URL::Encoding.unescape_path("file%5Cname")).to be == "file%5Cname"
		end
	end
	
	describe ".escape_path" do
		it "escapes path with spaces" do
			expect(Protocol::URL::Encoding.escape_path("/path/with spaces/file.html")).to be == "/path/with%20spaces/file.html"
		end
		
		it "preserves path separators" do
			expect(Protocol::URL::Encoding.escape_path("/foo/bar")).to be == "/foo/bar"
		end
	end
	
	describe ".encode" do
		it "encodes simple parameters" do
			expect(Protocol::URL::Encoding.encode({"foo" => "bar"})).to be == "foo=bar"
		end
		
		it "encodes array parameters" do
			expect(Protocol::URL::Encoding.encode({"tags" => ["ruby", "http"]})).to be == "tags[]=ruby&tags[]=http"
		end
		
		it "encodes nested parameters" do
			result = Protocol::URL::Encoding.encode({"user" => {"name" => "Alice"}})
			expect(result).to be == "user[name]=Alice"
		end
	end
	
	describe ".assign" do
		let(:parameters) {Hash.new}
		
		it "assigns simple parameters" do
			keys = Protocol::URL::Encoding.split("foo")
			Protocol::URL::Encoding.assign(keys, "bar", parameters)
			expect(parameters).to be == {"foo" => "bar"}
		end
		
		it "assigns array parameters" do
			keys = Protocol::URL::Encoding.split("tags[]")
			Protocol::URL::Encoding.assign(keys, "ruby", parameters)
			Protocol::URL::Encoding.assign(keys, "http", parameters)
			expect(parameters).to be == {"tags" => ["ruby", "http"]}
		end
		
		it "assigns nested parameters" do
			keys = Protocol::URL::Encoding.split("user[name]")
			Protocol::URL::Encoding.assign(keys, "Alice", parameters)
			expect(parameters).to be == {"user" => {"name" => "Alice"}}
		end
		
		it "assigns array of objects with single property" do
			keys = Protocol::URL::Encoding.split("items[][name]")
			Protocol::URL::Encoding.assign(keys, "a", parameters)
			Protocol::URL::Encoding.assign(keys, "b", parameters)
			expect(parameters).to be == {"items" => [{"name" => "a"}, {"name" => "b"}]}
		end
		
		it "assigns array of objects with multiple properties" do
			keys_name = Protocol::URL::Encoding.split("items[][name]")
			keys_value = Protocol::URL::Encoding.split("items[][value]")
			
			Protocol::URL::Encoding.assign(keys_name, "a", parameters)
			Protocol::URL::Encoding.assign(keys_value, "1", parameters)
			Protocol::URL::Encoding.assign(keys_name, "b", parameters)
			Protocol::URL::Encoding.assign(keys_value, "2", parameters)
			
			expect(parameters).to be == {"items" => [{"name" => "a", "value" => "1"}, {"name" => "b", "value" => "2"}]}
		end
	end
	
	describe ".decode" do
		it "decodes simple parameters" do
			expect(Protocol::URL::Encoding.decode("foo=bar")).to be == {"foo" => "bar"}
		end
		
		it "decodes array parameters" do
			expect(Protocol::URL::Encoding.decode("tags[]=ruby&tags[]=http")).to be == {"tags" => ["ruby", "http"]}
		end
		
		it "decodes nested parameters" do
			expect(Protocol::URL::Encoding.decode("user[name]=Alice")).to be == {"user" => {"name" => "Alice"}}
		end
		
		it "symbolizes keys when requested" do
			result = Protocol::URL::Encoding.decode("foo=bar", symbolize_keys: true)
			expect(result).to be == {:foo => "bar"}
		end
		
		it "raises on deeply nested parameters" do
			expect do
				Protocol::URL::Encoding.decode("a[b][c][d][e][f][g][h][i]=value")
			end.to raise_exception(ArgumentError, message: be =~ /Key length exceeded/)
		end
		
		it "raises on empty key path" do
			expect do
				# A query string with empty key (just "=value")
				Protocol::URL::Encoding.decode("=value")
			end.to raise_exception(ArgumentError, message: be =~ /Invalid key path/)
		end
	end
	
	describe ".encode with prefix" do
		it "returns prefix for nil value" do
			result = Protocol::URL::Encoding.encode(nil, "prefix")
			expect(result).to be == "prefix"
		end
		
		it "handles nested array elements correctly" do
			# This tests the line: top -= 1 unless last.include?(nested)
			result = Protocol::URL::Encoding.encode({"items" => [{"name" => "a"}, {"name" => "b"}]})
			expect(result).to be(:include?, "items[][name]=a")
			expect(result).to be(:include?, "items[][name]=b")
		end
	end
end
