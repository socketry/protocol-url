# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/url"

# RFC 3986 Section 5.4 - Reference Resolution Examples
# Base URI: http://a/b/c/d;p?q

describe Protocol::URL::Reference do
	let(:base) { Protocol::URL["http://a/b/c/d;p?q"] }
	
	describe "normal examples" do
		it "resolves 'g:h'" do
			result = base + "g:h"
			expect(result.to_s).to be == "g:h"
		end
		
		it "resolves 'g'" do
			result = base + "g"
			expect(result.to_s).to be == "http://a/b/c/g"
		end
		
		it "resolves './g'" do
			result = base + "./g"
			expect(result.to_s).to be == "http://a/b/c/g"
		end
		
		it "resolves 'g/'" do
			result = base + "g/"
			expect(result.to_s).to be == "http://a/b/c/g/"
		end
		
		it "resolves '/g'" do
			result = base + "/g"
			expect(result.to_s).to be == "http://a/g"
		end
		
		it "resolves '//g'" do
			result = base + "//g"
			expect(result.to_s).to be == "http://g"
		end
		
		it "resolves '?y'" do
			result = base + "?y"
			expect(result.to_s).to be == "http://a/b/c/d;p?y"
		end
		
		it "resolves 'g?y'" do
			result = base + "g?y"
			expect(result.to_s).to be == "http://a/b/c/g?y"
		end
		
		it "resolves '#s'" do
			result = base + "#s"
			expect(result.to_s).to be == "http://a/b/c/d;p?q#s"
		end
		
		it "resolves 'g#s'" do
			result = base + "g#s"
			expect(result.to_s).to be == "http://a/b/c/g#s"
		end
		
		it "resolves 'g?y#s'" do
			result = base + "g?y#s"
			expect(result.to_s).to be == "http://a/b/c/g?y#s"
		end
		
		it "resolves ';x'" do
			result = base + ";x"
			expect(result.to_s).to be == "http://a/b/c/;x"
		end
		
		it "resolves 'g;x'" do
			result = base + "g;x"
			expect(result.to_s).to be == "http://a/b/c/g;x"
		end
		
		it "resolves 'g;x?y#s'" do
			result = base + "g;x?y#s"
			expect(result.to_s).to be == "http://a/b/c/g;x?y#s"
		end
		
		it "resolves ''" do
			result = base + ""
			expect(result.to_s).to be == "http://a/b/c/d;p?q"
		end
		
		it "resolves '.'" do
			result = base + "."
			expect(result.to_s).to be == "http://a/b/c/"
		end
		
		it "resolves './'" do
			result = base + "./"
			expect(result.to_s).to be == "http://a/b/c/"
		end
		
		it "resolves '..'" do
			result = base + ".."
			expect(result.to_s).to be == "http://a/b/"
		end
		
		it "resolves '../'" do
			result = base + "../"
			expect(result.to_s).to be == "http://a/b/"
		end
		
		it "resolves '../g'" do
			result = base + "../g"
			expect(result.to_s).to be == "http://a/b/g"
		end
		
		it "resolves '../..'" do
			result = base + "../.."
			expect(result.to_s).to be == "http://a/"
		end
		
		it "resolves '../../'" do
			result = base + "../../"
			expect(result.to_s).to be == "http://a/"
		end
		
		it "resolves '../../g'" do
			result = base + "../../g"
			expect(result.to_s).to be == "http://a/g"
		end
	end
	
	describe "abnormal examples" do
		it "resolves '../../../g'" do
			result = base + "../../../g"
			expect(result.to_s).to be == "http://a/g"
		end
		
		it "resolves '../../../../g'" do
			result = base + "../../../../g"
			expect(result.to_s).to be == "http://a/g"
		end
		
		it "resolves '/./g'" do
			result = base + "/./g"
			expect(result.to_s).to be == "http://a/g"
		end
		
		it "resolves '/../g'" do
			result = base + "/../g"
			expect(result.to_s).to be == "http://a/g"
		end
		
		it "resolves 'g.'" do
			result = base + "g."
			expect(result.to_s).to be == "http://a/b/c/g."
		end
		
		it "resolves '.g'" do
			result = base + ".g"
			expect(result.to_s).to be == "http://a/b/c/.g"
		end
		
		it "resolves 'g..'" do
			result = base + "g.."
			expect(result.to_s).to be == "http://a/b/c/g.."
		end
		
		it "resolves '..g'" do
			result = base + "..g"
			expect(result.to_s).to be == "http://a/b/c/..g"
		end
		
		it "resolves './../g'" do
			result = base + "./../g"
			expect(result.to_s).to be == "http://a/b/g"
		end
		
		it "resolves './g/.'" do
			result = base + "./g/."
			expect(result.to_s).to be == "http://a/b/c/g/"
		end
		
		it "resolves 'g/./h'" do
			result = base + "g/./h"
			expect(result.to_s).to be == "http://a/b/c/g/h"
		end
		
		it "resolves 'g/../h'" do
			result = base + "g/../h"
			expect(result.to_s).to be == "http://a/b/c/h"
		end
		
		it "resolves 'g;x=1/./y'" do
			result = base + "g;x=1/./y"
			expect(result.to_s).to be == "http://a/b/c/g;x=1/y"
		end
		
		it "resolves 'g;x=1/../y'" do
			result = base + "g;x=1/../y"
			expect(result.to_s).to be == "http://a/b/c/y"
		end
		
		it "resolves 'g?y/./x'" do
			result = base + "g?y/./x"
			expect(result.to_s).to be == "http://a/b/c/g?y/./x"
		end
		
		it "resolves 'g?y/../x'" do
			result = base + "g?y/../x"
			expect(result.to_s).to be == "http://a/b/c/g?y/../x"
		end
		
		it "resolves 'g#s/./x'" do
			result = base + "g#s/./x"
			expect(result.to_s).to be == "http://a/b/c/g#s/./x"
		end
		
		it "resolves 'g#s/../x'" do
			result = base + "g#s/../x"
			expect(result.to_s).to be == "http://a/b/c/g#s/../x"
		end
	end
end
