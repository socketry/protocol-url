# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "encoding"
require_relative "reference"

module Protocol
	module URL
		# Represents a relative URL (path-only).
		# Examples: "./app.js", "../lib/utils.js", "/components/button.js"
		class Relative
			def initialize(path, query = nil, fragment = nil)
				@path = path.to_s
				@query = query
				@fragment = fragment
			end
			
			attr :path
			attr :query
			attr :fragment
			
			# Combine this relative URL with another URL or path using Protocol::URL::Reference.
			#
			# @parameter other [String, Absolute, Relative, Reference] The URL or path to combine.
			# @returns [Absolute, Relative] The combined URL.
			def +(other)
				case other
				when Absolute
					# Relative + Absolute: the absolute URL takes precedence
					# You can't apply relative navigation to an absolute URL
					other
				when Relative
					# Relative + Relative: combine paths using Protocol::URL::Reference
					resolved_reference = to_reference + other.to_reference
					Relative.new(resolved_reference.path, resolved_reference.query, resolved_reference.fragment)
				when Reference
					# Relative + Reference: combine using Protocol::URL::Reference
					resolved_reference = to_reference + other
					Relative.new(resolved_reference.path, resolved_reference.query, resolved_reference.fragment)
				when String
					# Relative + String: parse and combine
					self + URL[other]
				else
					raise ArgumentError, "Cannot combine Relative URL with #{other.class}"
				end
			end
			
			# Convert to Protocol::URL::Reference.
			def to_reference
				Reference.new(@path, @query, @fragment)
			end
			
			# Append the relative URL to the given buffer.
			def append(buffer = String.new)
				if @query and !@query.empty?
					buffer << Encoding.escape_path(@path) << "?" << @query
				else
					buffer << Encoding.escape_path(@path)
				end
				
				if @fragment and !@fragment.empty?
					buffer << "#" << Encoding.escape_fragment(@fragment)
				end
				
				return buffer
			end
			
			def to_s
				append
			end
			
			def absolute?
				false
			end
			
			def relative?
				true
			end
			
			def inspect
				"#<#{self.class} #{to_s}>"
			end
		end
	end
end
