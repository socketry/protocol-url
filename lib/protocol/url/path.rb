# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "encoding"

module Protocol
	module URL
		# Represents a URL path without losing the boundary between URL path components.
		#
		# String input is interpreted as an encoded URL path. Array input is interpreted as
		# decoded components. A literal `/` in an encoded string is structural, while `%2F`
		# decodes to data within a single component.
		class Path
			include Comparable
			
			# The path separator.
			SEPARATOR = "/"
			EMPTY_COMPONENTS = [].freeze
			ROOT_COMPONENTS = ["", ""].freeze
			INVALID_COMPONENT_PATTERN = /([^a-zA-Z0-9_\-\.~!$&'()*+,;=:@]+)/.freeze
			private_constant :EMPTY_COMPONENTS, :ROOT_COMPONENTS, :INVALID_COMPONENT_PATTERN
			
			# Coerce an encoded string or decoded component array into a path.
			#
			# @parameter path [String | Array(String) | Path] The value to coerce.
			# @returns [Path] The coerced path, or the existing path unchanged.
			def self.[](path)
				if path.is_a?(self)
					return path
				elsif path.is_a?(Array)
					return self.new(nil, path)
				else
					return self.new(path.to_s)
				end
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
				return Path[target].relative(from).to_s
			end
			
			# Initialize a path from either its encoded representation or decoded components.
			#
			# @parameter encoded [String | Nil] The encoded URL path.
			# @parameter components [Array(String) | Nil] The decoded path components.
			def initialize(encoded, components = nil)
				@encoded = encoded
				
				if components == [""]
					components = ROOT_COMPONENTS
				elsif encoded.nil? && components.nil?
					components = EMPTY_COMPONENTS
				elsif components && !components.frozen?
					# Only dup if we need to:
					components = components.dup.freeze
				end
				
				@components = components
			end
			
			# @returns [Boolean] Whether the path begins at the URL path root.
			def absolute?
				if @encoded
					return @encoded.start_with?(SEPARATOR)
				end
				
				return @components.first == ""
			end
			
			# @returns [Boolean] Whether the path is relative to another URL path.
			def relative?
				!absolute?
			end
			
			# @returns [Boolean] Whether the path has a trailing separator.
			def directory?
				if @encoded
					return @encoded.end_with?(SEPARATOR)
				end
				
				return @components.last == ""
			end
			
			# The final decoded component. A path with a trailing separator has an empty basename.
			#
			# @parameter extension [Boolean] Whether to include the final file extension.
			# @returns [String | Nil] The final component, or `nil` for an empty path.
			def basename(extension: true)
				component = self.components.last
				return component if extension || component.nil?
				
				if index = component.rindex(".")
					basename = component[0...index]
					return basename if basename.b.match?(/[^.]/n)
				end
				
				return component
			end
			
			# Return a path with its final component removed.
			#
			# The empty path and absolute root are their own parents. For a directory path,
			# this removes the trailing empty component which represents its separator.
			#
			# @parameter level [Integer] The number of components to remove.
			# @returns [Path] The parent path.
			# @raises [ArgumentError] If `level` is not a non-negative integer.
			def parent(level = 1)
				unless level.is_a?(Integer) && level >= 0
					raise ArgumentError, "Path parent level must be a non-negative integer!"
				end
				
				components = self.components
				return self if level == 0 || components.empty? || components == ROOT_COMPONENTS
				
				remaining = components.size - level
				if absolute?
					components = remaining <= 1 ? ROOT_COMPONENTS : components.first(remaining)
				else
					components = remaining <= 0 ? EMPTY_COMPONENTS : components.first(remaining)
				end
				
				return self.class.new(nil, components)
			end
			
			# @returns [Array(String)] The decoded components, preserving their boundaries.
			def components
				@components ||= @encoded.split(SEPARATOR, -1).map! do |component|
					Encoding.unescape(component)
				end.freeze
			end
			
			# @returns [String] The encoded URL path.
			def encoded
				@encoded ||= @components.map{|component|
					component.b.gsub(INVALID_COMPONENT_PATTERN) do |match|
						"%" + match.unpack("H2" * match.bytesize).join("%").upcase
					end.force_encoding(component.encoding)
				}.join(SEPARATOR).freeze
			end
			
			# @returns [Boolean] Whether the path contains no components.
			def empty?
				components.empty?
			end
			
			# Paths compare by their decoded components, not by their encoded spelling.
			# Component boundaries remain significant, so `%2F` within a component is
			# distinct from a literal `/` separating two components.
			def <=>(other)
				return nil unless other.is_a?(Path)
				
				components <=> other.components
			end
			
			# @parameter other [Object] The value to compare with this path.
			# @returns [Boolean] Whether both paths have the same decoded components.
			def ==(other)
				other.is_a?(Path) && components == other.components
			end
			
			alias eql? ==
			
			# @returns [Integer] A hash derived from the decoded components.
			def hash
				components.hash
			end
			
			FILESYSTEM_ENCODING = ::Encoding.find("filesystem")
			FILESYSTEM_INVALID_PATTERN = Regexp.union(["\0", File::SEPARATOR, File::ALT_SEPARATOR].compact)
			private_constant :FILESYSTEM_ENCODING, :FILESYSTEM_INVALID_PATTERN
			
			# Convert a URL path to a local file system path.
			#
			# Each decoded URL component must map to exactly one local path component. Components
			# containing NUL or a platform path separator cannot be represented and are rejected.
			#
			# @parameter encoding [Encoding] The target file system encoding.
			# @returns [String] The local file system path.
			#
			# This conversion does not simplify `.` or `..` components or establish containment
			# beneath an application root. Simplify and apply the application's containment
			# policy before using a path from an untrusted source.
			def local_path(encoding: FILESYSTEM_ENCODING)
				components = self.components.map do |component|
					unless component.valid_encoding?
						raise ArgumentError, "Path has invalid encoding!"
					end
					
					if FILESYSTEM_INVALID_PATTERN.match?(component)
						raise ArgumentError, "Path contains invalid characters!"
					end
					
					component.encode(encoding)
				end
				
				return File.join(*components)
			rescue ::Encoding::InvalidByteSequenceError, ::Encoding::UndefinedConversionError
				raise ArgumentError, "Path could not be converted to a local path!"
			end
			
			alias to_s encoded
			alias to_str encoded
			
			# Simplify this path in place by resolving dot segments and repeated separators.
			#
			# @returns [Path | Nil] This path when changed, otherwise `nil`.
			def simplify!
				simplified = simplify
				return nil if simplified.equal?(self)
				
				@encoded = simplified.encoded
				@components = simplified.components
				
				return self
			end
			
			# Return a canonical path by resolving dot segments and repeated separators.
			#
			# Absolute paths do not retain parent components above the root. Relative paths
			# retain leading parent components which cannot be resolved locally.
			#
			# @returns [Path] The simplified path, or this path if already canonical.
			def simplify
				components = simplify_components
				return self unless components
				
				return self.class.new(nil, components)
			end
			
			# Resolve another path relative to this path.
			#
			# @parameter other [String | Array(String) | Path] The path to resolve.
			# @parameter pop [Boolean] Whether to remove the final base component first.
			# @parameter simplify [Boolean] Whether to simplify the resulting components.
			# @returns [Path] The resolved path.
			def join(other, pop: true, simplify: true)
				other = Path[other]
				return self if other.empty?
				
				if other.absolute?
					return simplify ? other.simplify : other
				end
				
				components = self.components.dup
				
				# RFC2396 Section 5.2:
				# 6) a) All but the last segment of the base URI's path component is
				# copied to the buffer.  In other words, any characters after the
				# last (right-most) slash character, if any, are excluded.
				if pop and components.last != ".."
					components.pop
				elsif components.last == ""
					components.pop
				end
				
				components.concat(other.components)
				
				if simplify
					simplify_components!(components)
				end
				
				return Path.new(nil, components)
			end
			
			# Calculate this path relative to another path.
			#
			# @parameter from [String | Array(String) | Path] The source path.
			# @returns [Path] The relative path from `from` to this path.
			def relative(from)
				target_components = self.components
				from_components = Path[from].components
				
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
				
				return Path.new(nil, relative_components)
			end
			
			private
			
			# Find the first component which requires simplification.
			def simplification_index(components)
				absolute = components.first == ""
				regular_component = false
				last_index = components.size - 1
				
				components.each_with_index do |component, index|
					if component == "."
						return index
					elsif component == ""
						# Leading and trailing empty components are significant.
						return index if index > 0 && index < last_index
					elsif component == ".."
						# Absolute paths cannot retain parent components. Relative paths
						# can retain them only before the first regular component.
						return index if absolute || regular_component
					else
						regular_component = true
					end
				end
				
				return nil
			end
			
			# Return simplified components, or nil if they are already canonical.
			def simplify_components
				components = self.components
				return nil unless start_index = simplification_index(components)
				
				components = components.dup
				simplify_components!(components, start_index)
				
				return components
			end
			
			# Simplify the given components in place.
			def simplify_components!(components, start_index = nil)
				start_index ||= simplification_index(components)
				return nil unless start_index
				
				offset = start_index
				index = start_index
				last_index = components.size - 1
				
				while index <= last_index
					component = components[index]
					
					if component == "."
						# A trailing dot denotes a directory.
						if index == last_index
							components[offset] = ""
							offset += 1
						end
					elsif component == "" && index != last_index
						# Collapse repeated separators.
					elsif component == ".." && offset > 0 && components[offset - 1] != ".."
						# Pop a component, but never pop the absolute-path root.
						offset -= 1 if components[offset - 1] != ""
						
						# A trailing parent reference also denotes a directory.
						if index == last_index
							components[offset] = ""
							offset += 1
						end
					else
						components[offset] = component if offset < index
						offset += 1
					end
					
					index += 1
				end
				
				if offset < components.size
					components[offset, components.size - offset] = EMPTY_COMPONENTS
				end
				
				return components
			end
		end
	end
end
