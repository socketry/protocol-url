# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Protocol
	module URL
		# Helpers for encoding and decoding URL components.
		module Encoding
			# Escapes a string using percent encoding, e.g. `a b` -> `a%20b`.
			#
			# @parameter string [String] The string to escape.
			# @returns [String] The escaped string.
			#
			# @example Escape spaces and special characters.
			# 	Encoding.escape("hello world!")
			# 	# => "hello%20world%21"
			#
			# @example Escape unicode characters.
			# 	Encoding.escape("café")
			# 	# => "caf%C3%A9"
			def self.escape(string, encoding = string.encoding)
				string.b.gsub(/([^a-zA-Z0-9_.\-]+)/) do |m|
					"%" + m.unpack("H2" * m.bytesize).join("%").upcase
				end.force_encoding(encoding)
			end
			
			# Unescapes a percent encoded string, e.g. `a%20b` -> `a b`.
			#
			# @parameter string [String] The string to unescape.
			# @returns [String] The unescaped string.
			# @raises [ArgumentError] If the string contains malformed percent encoding.
			#
			# @example Unescape spaces and special characters.
			# 	Encoding.unescape("hello%20world%21")
			# 	# => "hello world!"
			#
			# @example Unescape unicode characters.
			# 	Encoding.unescape("caf%C3%A9")
			# 	# => "café"
			def self.unescape(string, encoding = string.encoding)
				string.b.gsub(/%([0-9A-Fa-f]{2})?/) do
					unless hexadecimal = $1
						raise ArgumentError, "String contains malformed percent encoding!"
					end
					
					Integer(hexadecimal, 16).chr
				end.force_encoding(encoding)
			end
			
			# Maps individual URL path segments to and from local filesystem components.
			#
			# Unlike generic URL decoding, this encoding rejects values which would turn one
			# URL segment into multiple local path components.
			module System
				ENCODING = ::Encoding.find("filesystem")
				INVALID_CHARACTER_PATTERN = Regexp.union(["\0", File::SEPARATOR, File::ALT_SEPARATOR].compact)
				
				# Encode one local filesystem component as one URL path segment.
				# @parameter component [String] The local filesystem component.
				# @returns [String] The encoded URL segment.
				# @raises [ArgumentError] If the component cannot be converted or contains a system path separator.
				def self.escape(component)
					validate(component)
					Encoding.escape(transcode(component, ::Encoding::UTF_8))
				end
				
				# Decode one URL path segment as one local filesystem component.
				# @parameter segment [String] The encoded URL segment.
				# @returns [String] The local filesystem component.
				# @raises [ArgumentError] If the segment cannot map to one local filesystem component.
				def self.unescape(segment)
					component = Encoding.unescape(segment, ::Encoding::UTF_8)
					validate(component)
					transcode(component, ENCODING)
				end
				
				# Transcode a path component to the requested character encoding.
				def self.transcode(component, encoding)
					component.encode(encoding)
				rescue ::Encoding::InvalidByteSequenceError, ::Encoding::UndefinedConversionError
					raise ArgumentError, "Path component could not be transcoded!"
				end
				
				# Validate that a string can represent exactly one local filesystem component.
				def self.validate(component)
					unless component.valid_encoding?
						raise ArgumentError, "Path component has invalid encoding!"
					end
					
					if INVALID_CHARACTER_PATTERN.match?(component)
						raise ArgumentError, "Path component contains invalid characters!"
					end
				end
				private_class_method :transcode, :validate
				private_constant :ENCODING, :INVALID_CHARACTER_PATTERN
			end
			
			# Matches characters that are not allowed in a URI fragment. According to RFC 3986 Section 3.5, a valid fragment consists of pchar / "/" / "?" characters.
			NON_FRAGMENT_CHARACTER_PATTERN = /([^a-zA-Z0-9_\-\.~!$&'()*+,;=:@\/\?]+)/.freeze
			
			# Escapes non-fragment characters using percent encoding. According to RFC 3986 Section 3.5, fragments can contain pchar / "/" / "?" characters.
			#
			# @parameter fragment [String] The fragment to escape.
			# @returns [String] The escaped fragment.
			def self.escape_fragment(fragment)
				encoding = fragment.encoding
				fragment.b.gsub(NON_FRAGMENT_CHARACTER_PATTERN) do |m|
					"%" + m.unpack("H2" * m.bytesize).join("%").upcase
				end.force_encoding(encoding)
			end
			
			# Encodes a hash or array into a query string. This method is used to encode query parameters in a URL. For example, `{"a" => 1, "b" => 2}` is encoded as `a=1&b=2`.
			#
			# @parameter value [Hash | Array | Nil] The value to encode.
			# @parameter prefix [String] The prefix to use for keys.
			#
			# @example Encode simple parameters.
			# 	Encoding.encode({"name" => "Alice", "age" => "30"})
			# 	# => "name=Alice&age=30"
			#
			# @example Encode nested parameters.
			# 	Encoding.encode({"user" => {"name" => "Alice", "role" => "admin"}})
			# 	# => "user[name]=Alice&user[role]=admin"
			def self.encode(value, prefix = nil)
				case value
				when Array
					return value.map {|v|
						self.encode(v, "#{prefix}[]")
					}.join("&")
				when Hash
					return value.map {|k, v|
						self.encode(v, prefix ? "#{prefix}[#{escape(k.to_s)}]" : escape(k.to_s))
					}.reject(&:empty?).join("&")
				when nil
					return prefix
				else
					raise ArgumentError, "value must be a Hash" if prefix.nil?
					
					return "#{prefix}=#{escape(value.to_s)}"
				end
			end
			
			# Scan a string for URL-encoded key/value pairs.
			# @yields {|key, value| ...}
			# 	@parameter key [String] The unescaped key.
			# 	@parameter value [String] The unescaped key.
			def self.scan(string)
				string.split("&") do |assignment|
					next if assignment.empty?
					
					key, value = assignment.split("=", 2)
					
					yield unescape(key), value.nil? ? value : unescape(value)
				end
			end
			
			# Split a key into parts, e.g. `a[b][c]` -> `["a", "b", "c"]`.
			#
			# @parameter name [String] The key to split.
			# @returns [Array(String)] The parts of the key.
			def self.split(name)
				name.scan(/([^\[]+)|(?:\[(.*?)\])/)&.tap do |parts|
					parts.flatten!
					parts.compact!
				end
			end
			
			# Assign a value to a nested hash.
			#
			# This method handles building nested data structures from query string parameters, including arrays of objects. When processing array elements (empty key like `[]`), it intelligently decides whether to add to the last array element or create a new one.
			#
			# @parameter keys [Array(String)] The parts of the key.
			# @parameter value [Object] The value to assign.
			# @parameter parent [Hash] The parent hash.
			#
			# @example Building an array of objects.
			# 	# Query: items[][name]=a&items[][value]=1&items[][name]=b&items[][value]=2
			# 	# When "name" appears again, it creates a new array element
			# 	# Result: {"items" => [{"name" => "a", "value" => "1"}, {"name" => "b", "value" => "2"}]}
			def self.assign(keys, value, parent)
				top, *middle = keys
				
				middle.each_with_index do |key, index|
					if key.nil? or key.empty?
						# Array element (e.g., items[]):
						parent = (parent[top] ||= Array.new)
						top = parent.size
						
						# Check if we should reuse the last array element or create a new one. If there's a nested key coming next, and the last array element already has that key, then we need a new array element. Otherwise, add to the existing one.
						if nested = middle[index+1] and last = parent.last
							# If the last element doesn't include the nested key, reuse it (decrement index).
							# If it does include the key, keep current index (creates new element).
							top -= 1 unless last.include?(nested)
						end
					else
						# Hash key (e.g., user[name]):
						parent = (parent[top] ||= Hash.new)
						top = key
					end
				end
				
				parent[top] = value
			end
			
			# Decode a URL-encoded query string into a hash.
			#
			# @parameter string [String] The query string to decode.
			# @parameter maximum [Integer] The maximum number of keys in a path.
			# @parameter symbolize_keys [Boolean] Whether to symbolize keys.
			# @returns [Hash] The decoded query string.
			#
			# @example Decode simple parameters.
			# 	Encoding.decode("name=Alice&age=30")
			# 	# => {"name" => "Alice", "age" => "30"}
			#
			# @example Decode nested parameters.
			# 	Encoding.decode("user[name]=Alice&user[role]=admin")
			# 	# => {"user" => {"name" => "Alice", "role" => "admin"}}
			def self.decode(string, maximum = 8, symbolize_keys: false)
				parameters = {}
				
				self.scan(string) do |name, value|
					keys = self.split(name)
					
					if keys.empty?
						raise ArgumentError, "Invalid key path: #{name.inspect}!"
					end
					
					if keys.size > maximum
						raise ArgumentError, "Key length exceeded limit!"
					end
					
					if symbolize_keys
						keys.collect!{|key| key.empty? ? nil : key.to_sym}
					end
					
					self.assign(keys, value, parameters)
				end
				
				return parameters
			end
			
			# Decode an `application/x-www-form-urlencoded` string into a hash.
			# In addition to percent encoding, this format represents spaces using `+`.
			#
			# @parameter string [String] The form-encoded string to decode.
			# @parameter maximum [Integer] The maximum number of keys in a path.
			# @parameter symbolize_keys [Boolean] Whether to symbolize keys.
			# @returns [Hash] The decoded form values.
			def self.decode_www_form(string, maximum = 8, symbolize_keys: false)
				return self.decode(string.gsub("+", "%20"), maximum, symbolize_keys: symbolize_keys)
			end
		end
	end
end
