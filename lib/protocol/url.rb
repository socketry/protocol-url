# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "url/version"
require_relative "url/encoding"
require_relative "url/reference"
require_relative "url/relative"
require_relative "url/absolute"

module Protocol
	# Helpers for working with URLs.
	module URL
		# RFC 3986 URI pattern with named capture groups.
		# Matches: [scheme:][//authority][path][?query][#fragment]
		PATTERN = %r{
			\A
			(?:(?<scheme>[a-z][a-z0-9+.-]*):)?      # scheme (optional)
			(?<authority>//[^/?#]*)?                # authority with // (optional)
			(?<path>[^?#]*)                         # path
			(?:\?(?<query>[^#]*))?                  # query (optional)
			(?:\#(?<fragment>.*))?                  # fragment (optional)
			\z
		}ix
		
		# Coerce a value into an appropriate URL type (Absolute or Relative).
		#
		# @parameter value [String, Absolute, Relative, nil] The value to coerce.
		# @returns [Absolute, Relative, nil] The coerced URL.
		def self.[](value)
			case value
			when String
				if match = value.match(PATTERN)
					scheme = match[:scheme]
					authority = match[:authority]
					path = match[:path]
					query = match[:query]
					fragment = match[:fragment]
					
					# Strip the "//" prefix from authority
					authority = authority[2..-1] if authority
					
					# Decode the fragment if present
					fragment = Encoding.unescape(fragment) if fragment
					
					# If we have a scheme or authority, it's an absolute URL
					if scheme || authority
						Absolute.new(scheme, authority, path, query, fragment)
					else
						# No scheme or authority, treat as relative:
						Relative.new(path, query, fragment)
					end
				else
					raise ArgumentError, "Invalid URL: #{value}"
				end
			when Relative
				value
			when nil
				nil
			else
				raise ArgumentError, "Cannot coerce #{value.inspect} to URL!"
			end
		end
	end
end
