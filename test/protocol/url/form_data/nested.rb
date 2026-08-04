# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/url/form_data/nested"

describe Protocol::URL::FormData::Nested do
	let(:nested) {subject.new}
	
	it "builds nested hashes and arrays" do
		nested.add("user[name]", "Samuel")
		nested.add("user[roles][]", "admin")
		nested.add("user[roles][]", "editor")
		
		expect(nested.to_h).to be == {
			"user" => {"name" => "Samuel", "roles" => ["admin", "editor"]},
		}
	end
	
	it "preserves absent and empty values" do
		nested.add("absent", nil)
		nested.add("empty", "")
		
		expect(nested.to_h).to be == {"absent" => nil, "empty" => ""}
	end
	
	it "returns itself when adding a value" do
		expect(nested.add("name", "Samuel")).to be_equal(nested)
	end
	
	it "rejects empty names" do
		expect do
			nested.add("", "value")
		end.to raise_exception(ArgumentError, message: be =~ /Invalid form data name/)
	end
	
	it "limits nested names" do
		nested = subject.new(depth_limit: 2)
		
		expect do
			nested.add("a[b][c]", "value")
		end.to raise_exception(RangeError, message: be =~ /depth exceeded/)
	end
	
	it "allows the nesting limit to be disabled" do
		nested = subject.new(depth_limit: nil)
		nested.add("a[b][c]", "value")
		
		expect(nested.to_h).to be == {"a" => {"b" => {"c" => "value"}}}
	end
end
