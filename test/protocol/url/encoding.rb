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
	end
end
