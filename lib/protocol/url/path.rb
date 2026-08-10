# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "encoding"
require_relative "invalid_path_error"

module Protocol
	module URL
		# Represents a relative URL, which does not include a scheme or authority.
		module Path
			SEPARATOR = "/"
			
			# Split the given path into its components.
			# 
			# - `split("")` => `[]`
			# - `split("/")` => `["", ""]`
			# - `split("/a/b/c")` => `["", "a", "b", "c"]`
			# - `split("a/b/c/")` => `["a", "b", "c", ""]`
			#
			# @parameter path [String] The path to split.
			# @returns [Array(String)] The path components.
			#
			# @example Split an absolute path.
			# 	Path.split("/documents/report.pdf")
			# 	# => ["", "documents", "report.pdf"]
			#
			# @example Split a relative path.
			# 	Path.split("images/logo.png")
			# 	# => ["images", "logo.png"]
			def self.split(path)
				return path.split("/", -1)
			end
			
			# Parse an untrusted, encoded URL path into canonical components.
			#
			# Literal characters must match the ASCII path grammar from RFC 3986;
			# all other octets must be percent-encoded. Unreserved percent escapes
			# are decoded, remaining escapes are canonicalized, and dot segments are
			# resolved. Encoded separators remain within their original component.
			#
			# Absolute paths cannot traverse above their root. Leading parent segments
			# in relative paths are preserved for later resolution against a base path.
			#
			# This is the validation boundary for external URL paths. {.split} is a
			# lossless lexical operation and does not provide the same guarantee.
			#
			# @parameter path [String] The encoded URL path.
			# @returns [Array(String)] The validated, canonical path components.
			# @raises [InvalidPathError] If the path is malformed or unsafe.
			def self.parse(path)
				unless path.encoding.ascii_compatible?
					raise InvalidPathError.new(path, "parsed", "its encoding is not ASCII-compatible")
				end
				
				components = split(path.b)
				components.map! do |component|
					parse_component(path, component).force_encoding(path.encoding)
				end
				
				absolute = components.first == ""
				
				if absolute
					depth = 0
					
					components.drop(1).each do |component|
						if component.empty? || component == "."
							next
						elsif component == ".."
							if depth.zero?
								raise InvalidPathError.new(path, "parsed", "it traverses above the root")
							end
							
							depth -= 1
						else
							depth += 1
						end
					end
				end
				
				components = simplify(components)
				
				# A relative path that resolves completely to the current directory has
				# the same canonical representation as an empty relative path.
				components.clear if !absolute && components == [""]
				
				return components
			end
			
			# Join the given path components into a single path.
			#
			# @parameter components [Array(String)] The path components to join.
			# @returns [String] The joined path.
			#
			# @example Join absolute path components.
			# 	Path.join(["", "documents", "report.pdf"])
			# 	# => "/documents/report.pdf"
			#
			# @example Join relative path components.
			# 	Path.join(["images", "logo.png"])
			# 	# => "images/logo.png"
			def self.join(components)
				return components.join("/")
			end
			
			# Simplify trusted path components by resolving "." and "..".
			#
			# This is a structural operation for paths that are already trusted. It does
			# not validate URI syntax, decode percent escapes, or reject traversal above
			# an absolute root. Use {.parse} for an untrusted, encoded URL path.
			#
			# @parameter components [Array(String)] The path components to simplify.
			# @returns [Array(String)] The simplified path components.
			#
			# @example Resolve parent directory references.
			# 	Path.simplify(["documents", "reports", "..", "invoices", "2024.pdf"])
			# 	# => ["documents", "invoices", "2024.pdf"]
			#
			# @example Remove current directory references.
			# 	Path.simplify(["documents", ".", "report.pdf"])
			# 	# => ["documents", "report.pdf"]
			def self.simplify(components)
				output = []
				
				components.each_with_index do |component, index|
					if index == 0 && component == ""
						# Preserve leading slash:
						output << ""
					elsif component == "."
						# Handle current directory - trailing . means directory, preserve trailing slash:
						output << "" if index == components.size - 1
					elsif component == "" && index != components.size - 1
						# Ignore empty segments (multiple slashes) except at end - no-op.
					elsif component == ".." && output.last && output.last != ".."
						# Handle parent directory: go up one level if not at root:
						output.pop if output.last != ""
						# Trailing .. means directory, preserve trailing slash:
						output << "" if index == components.size - 1
					else
						# Regular path component:
						output << component
					end
				end
				
				return output
			end
			
			# @parameter pop [Boolean] whether to remove the last path component of the base path, to conform to URI merging behaviour, as defined by RFC2396.
			#
			# @example Expand a relative path against a base path.
			# 	Path.expand("/documents/reports/", "invoices/2024.pdf")
			# 	# => "/documents/reports/invoices/2024.pdf"
			#
			# @example Navigate to parent directory.
			# 	Path.expand("/documents/reports/2024/", "../summary.pdf")
			# 	# => "/documents/reports/summary.pdf"
			def self.expand(base, relative, pop = true)
				# Empty relative path means no change:
				return base if relative.nil? || relative.empty?
				
				components = split(base)
				
				# RFC2396 Section 5.2:
				# 6) a) All but the last segment of the base URI's path component is
				# copied to the buffer.  In other words, any characters after the
				# last (right-most) slash character, if any, are excluded.
				if pop and components.last != ".."
					components.pop
				elsif components.last == ""
					components.pop
				end
				
				relative = relative.split("/", -1)
				if relative.first == ""
					components = relative
				else
					components.concat(relative)
				end
				
				return join(simplify(components))
			end
			
			# Calculate the relative path from one absolute path to another.
			#
			# This is useful for generating relative URLs from one location to another,
			# such as creating page-specific import maps or relative links.
			#
			# @parameter target [String] The destination path (where you want to go).
			# @parameter from [String] The source path (where you are starting from).
			# @returns [String] The relative path from `from` to `target`.
			#
			# @example Calculate relative path between pages.
			# 	Path.relative("/_components/app.js", "/foo/bar/")
			# 	# => "../../_components/app.js"
			#
			# @example Calculate relative path in same directory.
			# 	Path.relative("/docs/guide.html", "/docs/index.html")
			# 	# => "guide.html"
			def self.relative(target, from)
				target_components = split(target)
				from_components = split(from)
				
				# Remove the last component from 'from' to get the directory
				from_components = from_components[0...-1] if from_components.size > 0
				
				# Find the common prefix
				common_length = 0
				[target_components.size, from_components.size].min.times do |i|
					break if target_components[i] != from_components[i]
					common_length = i + 1
				end
				
				# Calculate how many levels to go up
				up_levels = from_components.size - common_length
				
				# Build the relative path components
				relative_components = [".."] * up_levels + target_components[common_length..-1]
				
				return join(relative_components)
			end
			
			# Convert a URL path to a local file system path using the platform's file separator.
			#
			# String paths are parsed and validated first. Components already returned by
			# {.parse} can be passed directly. Each component is then decoded and joined
			# using `File.join`.
			#
			# Encoded separators that would become separators on the local platform are
			# rejected because they cannot be represented faithfully as one filesystem
			# component. In particular, `%2F` is rejected on all platforms and `%5C` is
			# rejected when backslash is a platform separator.
			#
			# @parameter path [String | Array(String)] The encoded URL path or parsed components.
			# @returns [String] The local file system path.
			# @raises [InvalidPathError] If a component cannot be represented safely.
			#
			# @example Generating local paths.
			# 	Path.to_local_path("/documents/report.pdf")  # => "/documents/report.pdf"
			# 	Path.to_local_path(Path.parse("/files/My%20Document.txt"))  # => "/files/My Document.txt"
			#
			def self.to_local_path(path)
				components = path.is_a?(String) ? parse(path) : path
				encoded_path = path.is_a?(String) ? path : join(components)
				
				components = components.map do |component|
					if encoded_local_separator?(component)
						raise InvalidPathError.new(encoded_path, "converted to a local path", "it contains an encoded local path separator")
					end
					
					decoded = Encoding.unescape(component)
					
					if decoded.include?("\0")
						raise InvalidPathError.new(encoded_path, "converted to a local path", "it contains an encoded null byte")
					end
					
					decoded
				end
				
				return File.join(*components)
			end
			
			# Check whether a component contains an encoded platform path separator.
			# @parameter component [String] The encoded URL path component.
			# @parameter alternate_separator [String | Nil] The platform's alternate path separator.
			# @returns [Boolean] Whether the component contains an encoded local path separator.
			def self.encoded_local_separator?(component, alternate_separator = File::ALT_SEPARATOR)
				return true if component.match?(/%2F/i)
				return true if alternate_separator && component.match?(/%5C/i)
				
				return false
			end
			private_class_method :encoded_local_separator?
			
			# Parse and canonicalize one encoded URL path component.
			# @parameter path [String] The complete path, used for error reporting.
			# @parameter component [String] The encoded URL path component.
			# @returns [String] The canonical encoded component.
			def self.parse_component(path, component)
				output = String.new.b
				index = 0
				
				while index < component.bytesize
					byte = component.getbyte(index)
					
					if byte == 0 || byte < 32 || byte == 127
						raise InvalidPathError.new(path, "parsed", "it contains a control character")
					end
					
					if byte == 92
						raise InvalidPathError.new(path, "parsed", "it contains an ambiguous separator")
					end
					
					if byte == 35 || byte == 63
						raise InvalidPathError.new(path, "parsed", "it contains a query or fragment delimiter")
					end
					
					if byte == 37
						high = hexadecimal_value(component.getbyte(index + 1))
						low = hexadecimal_value(component.getbyte(index + 2))
						
						unless high && low
							raise InvalidPathError.new(path, "parsed", "it contains a malformed percent escape")
						end
						
						byte = (high << 4) | low
						
						if unreserved_byte?(byte)
							output << byte
						else
							output << format("%%%02X", byte)
						end
						
						index += 3
						next
					end
					
					unless path_character_byte?(byte)
						raise InvalidPathError.new(path, "parsed", "it contains a character outside the URI path grammar")
					end
					
					output << byte
					index += 1
				end
				
				return output
			end
			private_class_method :parse_component
			
			# Decode an ASCII hexadecimal digit.
			# @parameter byte [Integer | Nil] The byte to decode.
			# @returns [Integer | Nil] The decoded value, or `nil` for a non-hexadecimal byte.
			def self.hexadecimal_value(byte)
				if byte && byte >= 48 && byte <= 57
					return byte - 48
				end
				
				if byte && byte >= 65 && byte <= 70
					return byte - 55
				end
				
				if byte && byte >= 97 && byte <= 102
					return byte - 87
				end
			end
			private_class_method :hexadecimal_value
			
			# RFC 3986 `pchar`: unreserved / sub-delims / ":" / "@".
			def self.path_character_byte?(byte)
				return true if unreserved_byte?(byte)
				return true if byte == 33 || byte == 36 || byte == 38 || byte == 39
				return true if byte >= 40 && byte <= 43
				return true if byte == 44 || byte == 59 || byte == 61
				return true if byte == 58 || byte == 64
				
				return false
			end
			private_class_method :path_character_byte?
			
			# Check whether a byte is an RFC 3986 unreserved character.
			# @parameter byte [Integer] The byte to check.
			# @returns [Boolean] Whether the byte is unreserved.
			def self.unreserved_byte?(byte)
				if byte >= 65 && byte <= 90
					return true
				end
				
				if byte >= 97 && byte <= 122
					return true
				end
				
				if byte >= 48 && byte <= 57
					return true
				end
				
				if byte == 45 || byte == 46 || byte == 95 || byte == 126
					return true
				end
				
				return false
			end
			private_class_method :unreserved_byte?
		end
	end
end
