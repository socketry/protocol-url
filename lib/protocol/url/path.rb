# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "encoding"

module Protocol
	module URL
		# Represents a relative URL, which does not include a scheme or authority.
		module Path
			# Split the given path into its components.
			# 
			# - `split("")` => `[]`
			# - `split("/")` => `["", ""]`
			# - `split("/a/b/c")` => `["", "a", "b", "c"]`
			# - `split("a/b/c/")` => `["a", "b", "c", ""]`
			#
			# @parameter path [String] The path to split.
			# @returns [Array(String)] The path components.
			def self.split(path)
				return path.split("/", -1)
			end
			
			# Join the given path components into a single path.
			#
			# @parameter components [Array(String)] The path components to join.
			# @returns [String] The joined path.
			def self.join(components)
				return components.join("/")
			end
			
			# Simplify the given path components by resolving "." and "..".
			#
			# @parameter components [Array(String)] The path components to simplify.
			# @returns [Array(String)] The simplified path components.
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
		end
	end
end
