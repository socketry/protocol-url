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
			
			def initialize(path, query = nil, fragment = nil)
				@path = path.to_s
				@query = query
				@fragment = fragment
			end
			
			attr :path
			attr :query
			attr :fragment
			
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
			def with(path: nil, query: @query, fragment: @fragment, pop: true)
				self.class.new(Path.expand(@path, path, pop), query, fragment)
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
			
			def to_ary
				[@path, @query, @fragment]
			end
			
			def <=>(other)
				to_ary <=> other.to_ary
			end
			
			def to_s
				append
			end
			
			def inspect
				"#<#{self.class} #{to_s}>"
			end
		end
	end
end
