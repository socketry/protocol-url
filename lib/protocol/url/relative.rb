# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "encoding"
require_relative "path"

module Protocol
	module URL
		# Represents a relative URL, which does not include a scheme or authority.
		class Relative
			include Comparable
			
			# Initialize a new relative URL.
			#
			# @parameter path [String] The path component.
			# @parameter query [String, nil] The query string.
			# @parameter fragment [String, nil] The fragment identifier.
			def initialize(path, query = nil, fragment = nil)
				@path = path.to_s
				@query = query
				@fragment = fragment
			end
			
			# @attribute [String] The path component of the URL.
			attr :path
			
			# @attribute [String, nil] The query string component.
			attr :query
			
			# @attribute [String, nil] The fragment identifier.
			attr :fragment
			
			# Convert the URL path to a local filesystem path.
			#
			# @returns [String] The local filesystem path.
			def to_local_path
				Path.to_local_path(@path)
			end
			
			# @returns [Boolean] If there is a query string.
			def query?
				@query and !@query.empty?
			end
			
			# @returns [Boolean] If there is a fragment.
			def fragment?
				@fragment and !@fragment.empty?
			end
			
			# Combine this relative URL with another URL or path.
			#
			# @parameter other [String, Absolute, Relative] The URL or path to combine.
			# @returns [Absolute, Relative] The combined URL.
			#
			# @example Combine two relative paths.
			# 	base = Relative.new("/documents/reports/")
			# 	other = Relative.new("invoices/2024.pdf")
			# 	result = base + other
			# 	result.path  # => "/documents/reports/invoices/2024.pdf"
			#
			# @example Navigate to parent directory.
			# 	base = Relative.new("/documents/reports/archive/")
			# 	other = Relative.new("../../summary.pdf")
			# 	result = base + other
			# 	result.path  # => "/documents/summary.pdf"
			def +(other)
				case other
				when Absolute
					# Relative + Absolute: the absolute URL takes precedence
					# You can't apply relative navigation to an absolute URL
					other
				when Relative
					# Relative + Relative: merge paths directly
					self.class.new(
						Path.expand(self.path, other.path, true),
						other.query,
						other.fragment
					)
				when String
					# Relative + String: parse and combine
					self + URL[other]
				else
					raise ArgumentError, "Cannot combine Relative URL with #{other.class}"
				end
			end
			
			# Create a new Relative URL with modified components.
			#
			# @parameter path [String, nil] The path to merge with the current path.
			# @parameter query [String, nil] The query string to use.
			# @parameter fragment [String, nil] The fragment to use.
			# @parameter pop [Boolean] Whether to pop the last path component before merging.
			# @returns [Relative] A new Relative URL with the modified components.
			#
			# @example Update the query string.
			# 	url = Relative.new("/search", "query=ruby")
			# 	updated = url.with(query: "query=python")
			# 	updated.to_s  # => "/search?query=python"
			#
			# @example Append to the path.
			# 	url = Relative.new("/documents/")
			# 	updated = url.with(path: "report.pdf", pop: false)
			# 	updated.to_s  # => "/documents/report.pdf"
			def with(path: nil, query: @query, fragment: @fragment, pop: true)
				self.class.new(Path.expand(@path, path, pop), query, fragment)
			end
			
			# Normalize the path by resolving "." and ".." segments and removing duplicate slashes.
			#
			# This modifies the URL in-place by simplifying the path component:
			# - Removes "." segments (current directory)
			# - Resolves ".." segments (parent directory)
			# - Collapses multiple consecutive slashes to single slashes (except at start)
			#
			# @returns [self] The normalized URL.
			#
			# @example Basic normalization
			#   url = Relative.new("/foo//bar/./baz/../qux")
			#   url.normalize!
			#   url.path  # => "/foo/bar/qux"
			def normalize!
				components = Path.split(@path)
				normalized = Path.simplify(components)
				@path = Path.join(normalized)
				
				return self
			end
			
			# Append the relative URL to the given buffer.
			# The path, query, and fragment are expected to already be properly encoded.
			def append(buffer = String.new)
				buffer << @path
				
				if @query and !@query.empty?
					buffer << "?" << @query
				end
				
				if @fragment and !@fragment.empty?
					buffer << "#" << @fragment
				end
				
				return buffer
			end
			
			# Convert the URL to an array representation.
			#
			# @returns [Array] An array of `[path, query, fragment]`.
			def to_ary
				[@path, @query, @fragment]
			end
			
			# Compute a hash value for the URL based on its components.
			#
			# @returns [Integer] The hash value.
			def hash
				to_ary.hash
			end
			
			# Check if this URL is equal to another URL by comparing components.
			#
			# @parameter other [Relative] The URL to compare with.
			# @returns [Boolean] True if the URLs have identical components.
			def equal?(other)
				to_ary == other.to_ary
			end
			
			# Compare this URL with another for sorting purposes.
			#
			# @parameter other [Relative] The URL to compare with.
			# @returns [Integer] -1, 0, or 1 based on component-wise comparison.
			def <=>(other)
				to_ary <=> other.to_ary
			end
			
			# Check structural equality by comparing components.
			#
			# @parameter other [Relative] The URL to compare with.
			# @returns [Boolean] True if the URLs have identical components.
			def ==(other)
				to_ary == other.to_ary
			end
			
			# Check string equality, useful for case statements.
			#
			# @parameter other [String, Relative] The value to compare with.
			# @returns [Boolean] True if the string representations match.
			def ===(other)
				to_s === other
			end
			
			# Convert the URL to its string representation.
			#
			# @returns [String] The formatted URL string.
			def to_s
				append
			end
			
			# Convert the URL to a JSON-compatible representation.
			#
			# @returns [String] The URL as a string.
			def as_json(...)
				to_s
			end
			
			# Convert the URL to JSON.
			#
			# @returns [String] The JSON-encoded URL.
			def to_json(...)
				as_json.to_json(...)
			end
			
			# Generate a human-readable representation for debugging.
			#
			# @returns [String] A string like `#<Protocol::URL::Relative /path?query#fragment>`.
			def inspect
				"#<#{self.class} #{to_s}>"
			end
		end
	end
end
