# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "url/version"
require_relative "url/encoding"
require_relative "url/reference"
require_relative "url/relative"
require_relative "url/absolute"

module Protocol
	module URL
		# RFC 3986 URI pattern with named capture groups.
		# Matches: [scheme:][//authority][path][?query][#fragment]
		# Rejects strings containing whitespace or control characters (matching standard URI behavior).
		PATTERN = %r{
			\A
			(?:(?<scheme>[a-z][a-z0-9+.-]*):)?      # scheme (optional)
			(?://(?<authority>[^/?#\s]*))?          # authority (optional, without //, no whitespace)
			(?<path>[^?#\s]*)                       # path (no whitespace)
			(?:\?(?<query>[^#\s]*))?                # query (optional, no whitespace)
			(?:\#(?<fragment>[^\s]*))?              # fragment (optional, no whitespace)
			\z
		}ix
		private_constant :PATTERN
		
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
					
					# If we have a scheme or authority, it's an absolute URL
					if scheme || authority
						Absolute.new(scheme, authority, path, query, fragment)
					else
						# No scheme or authority, treat as relative:
						Relative.new(path, query, fragment)
					end
				else
					raise ArgumentError, "Invalid URL (contains whitespace or control characters): #{value.inspect}"
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
