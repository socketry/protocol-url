# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "encoding"

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
						expand_path(self.path, other.path, true),
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
			
			def absolute?
				false
			end
			
			def relative?
				true
			end
			
			def inspect
				"#<#{self.class} #{to_s}>"
			end
			
			private
			
			def split(path)
				if path.empty?
					[path]
				else
					path.split("/", -1)
				end
			end
			
			def expand_parts(path, parts)
				parts.each do |part|
					if part == "."
						# No-op (ignore current directory)
					elsif part == ".." and path.last and path.last != ".."
						if path.last != ""
							# We can go up one level:
							path.pop
						end
					else
						path << part
					end
				end
			end
			
			# @parameter pop [Boolean] whether to remove the last path component of the base path, to conform to URI merging behaviour, as defined by RFC2396.
			def expand_path(base, relative, pop = true)
				if relative.start_with? "/"
					return relative
				end
				
				path = split(base)
				
				# RFC2396 Section 5.2:
				# 6) a) All but the last segment of the base URI's path component is
				# copied to the buffer.  In other words, any characters after the
				# last (right-most) slash character, if any, are excluded.
				#
				# NOTE: Since ".." and "." are considered special path segments with
				# navigational meaning, we treat them intuitively: if the last segment
				# is ".." we don't pop it, as it's a navigation instruction rather than
				# a filename. This provides more intuitive behavior when combining relative
				# paths, which is not explicitly defined by the RFC.
				if (pop or path.last == "") and path.last != ".." and path.last != "."
					path.pop
				end
				
				parts = split(relative)
				expand_parts(path, parts)
				
				# Ensure absolute paths start with "":
				if path.first != "" and base.start_with?("/")
					path.unshift("")
				end
				
				return path.join("/")
			end
		end
	end
end
