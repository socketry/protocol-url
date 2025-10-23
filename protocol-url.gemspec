# frozen_string_literal: true

require_relative "lib/protocol/url/version"

Gem::Specification.new do |spec|
	spec.name = "protocol-url"
	spec.version = Protocol::URL::VERSION
	
	spec.summary = "Provides abstractions for working with URLs."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/protocol-url"
	
	spec.metadata = {
		"source_code_uri" => "https://github.com/socketry/protocol-url.git",
		"documentation_uri" => "https://socketry.github.io/protocol-url/",
	}
	
	spec.files = Dir.glob(["{lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.2"
end
