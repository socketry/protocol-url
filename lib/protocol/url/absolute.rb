# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "relative"

module Protocol
	module URL
		# Represents an absolute URL with scheme and/or authority.
		# Examples: "https://example.com/path", "//cdn.example.com/lib.js", "http://localhost/"
		class Absolute < Relative
			def initialize(scheme, authority, path = "/", query = nil, fragment = nil)
				@scheme = scheme
				@authority = authority
				
				# Initialize the parent Relative class with the path component
				super(path, query, fragment)
			end
			
			attr :scheme
			attr :authority
			
			# Combine this absolute URL with a relative reference according to RFC 3986 Section 5.
			#
			# @parameter other [String, Relative, Reference, Absolute] The reference to resolve.
			# @returns [Absolute, String] The resolved absolute URL.
			def +(other)
				case other
				when Absolute
					# If other is already absolute with a scheme, return it as-is:
					return other if other.scheme
					# Protocol-relative URL: inherit scheme from base:
					return Absolute.new(@scheme, other.authority, other.path, other.query, other.fragment)
				when Relative
					# Already a Relative, use directly:
				when Reference
					other = Relative.new(other.path, other.query, other.fragment)
				when String
					other = URL[other]
					# If parsing resulted in an Absolute URL, handle it:
					if other.is_a?(Absolute)
						return other if other.scheme
						# Protocol-relative URL: inherit scheme from base:
						return Absolute.new(@scheme, other.authority, other.path, other.query, other.fragment)
					end
				else
					raise ArgumentError, "Cannot combine Absolute URL with #{other.class}"
				end
				
				# RFC 3986 Section 5.3: Component Recomposition
				# At this point, other is a Relative URL
				
				# Check for special cases first:
				if other.path.empty?
					# Empty path - could be query-only or fragment-only reference:
					if other.query
						# Query replacement: use base path with new query:
						Absolute.new(@scheme, @authority, @path, other.query, other.fragment)
					else
						# Fragment-only: keep everything from base, just change fragment:
						Absolute.new(@scheme, @authority, @path, @query, other.fragment || @fragment)
					end
				elsif other.path.start_with?("/")
					# Absolute path: use base scheme+authority with new path:
					Absolute.new(@scheme, @authority, normalize_path(other.path), other.query, other.fragment)
				else
					# Relative path: merge with base path:
					merged_path = merge_paths(@path, other.path)
					normalized_path = normalize_path(merged_path)
					Absolute.new(@scheme, @authority, normalized_path, other.query, other.fragment)
				end
			end
			
			# Append the absolute URL to the given buffer.
			def append(buffer = String.new)
				buffer << @scheme << ":" if @scheme
				buffer << @authority if @authority
				super(buffer)
			end
			
			def to_s
				append
			end
			
			def absolute?
				true
			end
			
			def relative?
				false
			end
			
			private
			
			# Merge a base path with a relative path according to RFC 3986 Section 5.2.3
			def merge_paths(base, relative)
				# If base has authority and empty path, use "/" + relative
				if @authority && !@authority.empty? && base.empty?
					return "/" + relative
				end
				
				# Otherwise, remove everything after the last "/" in base and append relative
				if base.include?("/")
					base.sub(/\/[^\/]*\z/, "/") + relative
				else
					relative
				end
			end
			
			# Remove dot-segments from a path according to RFC 3986 Section 5.2.4
			def normalize_path(path)
				# Remember if path starts with "/" (absolute path)
				absolute = path.start_with?("/")
				# Remember if path ends with "/" or "/." or "/.."
				trailing_slash = path.end_with?("/") || path.end_with?("/.") || path.end_with?("/..")
				
				output = []
				input = path.split("/", -1)
				
				input.each do |segment|
					if segment == ".."
						# Go up one level (pop), but not beyond root
						output.pop unless output.empty? || (absolute && output.size == 1 && output.first == "")
					elsif segment != "." && segment != ""
						# Keep all segments except "." and empty
						output << segment
					end
				end
				
				# For absolute paths, ensure we start with /
				if absolute
					result = "/" + output.join("/")
				else
					result = output.join("/")
				end
				
				# Add trailing slash if original had one or ended with dot-segments
				result += "/" if trailing_slash && !result.end_with?("/")
				
				result
			end
		end
	end
end
