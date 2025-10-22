# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "encoding"
require_relative "path"

module Protocol
	module URL
		# Represents a relative URL, which does not include a scheme or authority.
		class Relative
			def initialize(path, query = nil, fragment = nil)
				@path = path.to_s
				@query = query
				@fragment = fragment
			end
			
			attr :path
			attr :query
			attr :fragment
			
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
			
			private def append_query(buffer = String.new)
				if @query and !@query.empty?
					buffer << "?" << @query
				end
				return buffer
			end
			
			# Append the relative URL to the given buffer.
			def append(buffer = String.new)
				buffer << Encoding.escape_path(@path)
				
				append_query(buffer)
				
				if @fragment and !@fragment.empty?
					buffer << "#" << Encoding.escape_fragment(@fragment)
				end
				
				return buffer
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
