# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

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
		
		it "rejects incomplete percent encoding" do
			expect do
				Protocol::URL::Encoding.unescape("value%2")
			end.to raise_exception(ArgumentError, message: be == "String contains malformed percent encoding!")
		end
		
		it "rejects non-hexadecimal percent encoding" do
			expect do
				Protocol::URL::Encoding.unescape("value%GG")
			end.to raise_exception(ArgumentError, message: be == "String contains malformed percent encoding!")
		end
		
		it "accepts syntactically valid percent encoding independently of character encoding" do
			result = Protocol::URL::Encoding.unescape("%FF")
			
			expect(result.bytes).to be == [0xFF]
		end
		
		it "decodes percent encoding only once" do
			expect(Protocol::URL::Encoding.unescape("%252F")).to be == "%2F"
		end
	end
	
	describe Protocol::URL::Encoding::System do
		it "escapes a local filesystem component" do
			expect(subject.escape("My File.txt")).to be == "My%20File.txt"
		end
		
		it "unescapes a URL segment using UTF-8" do
			segment = "%E2%9D%A4%EF%B8%8F.txt".b
			
			expect(subject.unescape(segment)).to be == "❤️.txt"
		end
		
		it "rejects decoded system path separators" do
			expect do
				subject.unescape("safe%2Fname")
			end.to raise_exception(ArgumentError, message: be == "Path component contains invalid characters!")
		end
		
		it "rejects invalid decoded character encoding" do
			expect do
				subject.unescape("%FF")
			end.to raise_exception(ArgumentError, message: be == "Path component has invalid encoding!")
		end
		
		it "rejects a local component which cannot be converted to UTF-8" do
			component = "\xFF".b
			
			expect do
				subject.escape(component)
			end.to raise_exception(ArgumentError, message: be == "Path component could not be transcoded!")
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
	
	describe ".decode_www_form" do
		it "decodes spaces represented by plus signs" do
			expect(Protocol::URL::Encoding.decode_www_form("query=hello+world")).to be == {"query" => "hello world"}
		end
		
		it "preserves percent-encoded plus signs" do
			expect(Protocol::URL::Encoding.decode_www_form("operator=%2B")).to be == {"operator" => "+"}
		end
		
		it "decodes nested values" do
			result = Protocol::URL::Encoding.decode_www_form("user[name]=Samuel+Williams")
			expect(result).to be == {"user" => {"name" => "Samuel Williams"}}
		end
		
		it "forwards decoding options" do
			result = Protocol::URL::Encoding.decode_www_form("user[name]=Samuel", symbolize_keys: true)
			expect(result).to be == {user: {name: "Samuel"}}
		end
		
		it "round trips absent and empty values" do
			encoded = Protocol::URL::Encoding.encode({"absent" => nil, "empty" => ""})
			
			expect(encoded).to be == "absent&empty="
			expect(Protocol::URL::Encoding.decode_www_form(encoded)).to be == {"absent" => nil, "empty" => ""}
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
