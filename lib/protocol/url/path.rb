# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require_relative "encoding"

module Protocol
	module URL
		# Represents a URL path without losing its encoded segment boundaries.
		#
		# String input is interpreted as an encoded URL path. A literal `/` is structural,
		# while `%2F` remains encoded data within a single segment. Decoding is explicit and
		# controlled by the encoding object passed to {components}.
		class Path
			include Comparable
			
			# The path separator.
			SEPARATOR = "/"
			
			EMPTY_SEGMENTS = [].freeze
			ROOT_SEGMENTS = ["", ""].freeze
			NORMALIZATION_PATTERN = /%[0-9A-Fa-f]{2}|%|[^a-zA-Z0-9_.~!$&'()*+,;=:@-]/
			private_constant :EMPTY_SEGMENTS, :ROOT_SEGMENTS, :NORMALIZATION_PATTERN
			
			# Coerce an encoded string or encoded segment array into a path.
			#
			# @parameter path [String | Array(String) | Path] The encoded value to coerce.
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
			
			# Construct a path from decoded components.
			#
			# Each component is escaped independently, so decoded `/` characters remain data
			# inside one encoded segment rather than becoming structural separators.
			#
			# @parameter components [Array(String)] The decoded path components.
			# @parameter encoding [Object] An object implementing `escape(String)`.
			# @returns [Path] The encoded path.
			# @raises [ArgumentError] If the encoding does not produce one valid encoded segment per component.
			def self.for(components, encoding: Encoding)
				segments = components.map do |component|
					segment = encoding.escape(component)
					
					unless segment.is_a?(String) && !segment.include?(SEPARATOR)
						raise ArgumentError, "Path encoding produced an invalid segment!"
					end
					
					segment
				end
				
				return self.new(nil, segments)
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
			
			# Initialize a path from either its complete encoded representation or encoded segments.
			#
			# @parameter encoded [String | Nil] The encoded URL path.
			# @parameter segments [Array(String) | Nil] The encoded path segments.
			# @raises [ArgumentError] If an encoded segment contains a structural separator.
			def initialize(encoded, segments = nil)
				if encoded
					@encoded = -encoded
				end
				
				if encoded.nil? && segments.nil?
					segments = EMPTY_SEGMENTS
				elsif segments
					segments.each do |segment|
						unless segment.is_a?(String) && !segment.include?(SEPARATOR)
							raise ArgumentError, "Path contains an invalid encoded segment!"
						end
					end
					
					segments = segments.map(&:-@).freeze
				end
				
				@segments = segments
			end
			
			# Freeze the path and materialize both lossless representations.
			# @returns [Path] The frozen path.
			def freeze
				return self if frozen?
				
				self.segments
				self.encoded
				
				return super
			end
			
			# @returns [Boolean] Whether the path begins at the URL path root.
			def absolute?
				encoded.start_with?(SEPARATOR)
			end
			
			# @returns [Boolean] Whether the path is relative to another URL path.
			def relative?
				!absolute?
			end
			
			# @returns [Boolean] Whether the path has a trailing separator.
			def directory?
				encoded.end_with?(SEPARATOR)
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
				
				segments = self.segments
				return self if level == 0 || segments.empty? || segments == ROOT_SEGMENTS
				
				remaining = segments.size - level
				if absolute?
					segments = remaining <= 1 ? ROOT_SEGMENTS : segments.first(remaining)
				else
					segments = remaining <= 0 ? EMPTY_SEGMENTS : segments.first(remaining)
				end
				
				return self.class.new(nil, segments)
			end
			
			# @returns [Array(String)] The encoded segments, preserving their exact spelling.
			def segments
				@segments ||= @encoded.split(SEPARATOR, -1).map!(&:-@).freeze
			end
			
			# Decode the path segments using the given encoding.
			#
			# The result is not cached because different encoding objects can produce different
			# component values. In particular, a decoded component may contain `/` without
			# changing its boundary in the returned array.
			#
			# @parameter encoding [Object] An object implementing `unescape(String)`.
			# @returns [Array(String)] The decoded components.
			def components(encoding = Encoding)
				segments.map{|segment| encoding.unescape(segment)}
			end
			
			# @returns [String] The encoded URL path.
			def encoded
				@encoded ||= @segments.join(SEPARATOR).freeze
			end
			
			# @returns [Boolean] Whether the path contains no components.
			def empty?
				encoded.empty?
			end
			
			# Paths compare by their exact encoded representation.
			def <=>(other)
				return nil unless other.is_a?(Path)
				
				encoded <=> other.encoded
			end
			
			# @parameter other [Object] The value to compare with this path.
			# @returns [Boolean] Whether both values are the same.
			def ==(other)
				if other.is_a?(String)
					return encoded == other
				else
					return eql?(other)
				end
			end
			
			# Compare this path with another path using exact encoded string identity.
			# @parameter other [Object] The value to compare with this path.
			# @returns [Boolean] Whether both paths are the same.
			def eql?(other)
				other.is_a?(Path) && encoded.eql?(other.encoded)
			end
			
			# @returns [Integer] A hash derived from the exact encoded representation.
			def hash
				encoded.hash
			end
			
			# Resolve a URL path beneath a local filesystem root.
			#
			# Each decoded URL component must map to exactly one local path component. Components
			# containing NUL or a platform path separator cannot be represented and are rejected.
			# Absolute URL paths are interpreted relative to `root`, not the filesystem root.
			#
			# @parameter root [String] The filesystem root beneath which to resolve the URL path.
			# @returns [String] The expanded local filesystem path.
			# @raises [ArgumentError] If a URL segment is invalid or the path escapes the specified root.
			#
			# This establishes lexical containment only. It does not resolve symbolic links or
			# prevent filesystem races while a returned path is subsequently opened.
			def local_path(root)
				root = File.expand_path(root)
				root_prefix = root.end_with?(File::SEPARATOR) ? root : root + File::SEPARATOR
				
				components = self.components(Encoding::System)
				components.shift if components.first == ""
				
				path = File.expand_path(File.join(root, *components))
				return path if path == root || path.start_with?(root_prefix)
				
				raise ArgumentError, "Path escapes the specified root!"
			end
			
			alias to_s encoded
			alias to_str encoded
			
			# Normalize the encoded spelling of this path.
			#
			# Percent-encoded unreserved characters are decoded, retained percent escapes
			# use uppercase hexadecimal digits, and literal characters outside the path
			# segment grammar are percent encoded. Reserved characters retain their
			# encoded or literal form because those forms are not generally equivalent.
			#
			# This operation preserves the path structure. Use {simplify} separately when
			# application semantics permit resolving dot segments or collapsing repeated separators.
			#
			# @returns [Path] The normalized path, or this path if already normalized.
			# @raises [ArgumentError] If the path contains malformed percent encoding, NUL, or invalid string encoding.
			def normalize
				encoded = self.encoded
				unless encoded.valid_encoding? && encoded.encoding.ascii_compatible?
					raise ArgumentError, "Path segment has invalid encoding!"
				end
				
				segments = self.segments
				normalized_segments = nil
				
				segments.each_with_index do |segment, index|
					next unless NORMALIZATION_PATTERN.match?(segment)
					
					normalized = normalize_segment(segment)
					next if normalized == segment
					
					normalized_segments ||= segments.dup
					normalized_segments[index] = normalized
				end
				
				return self unless normalized_segments
				
				return self.class.new(nil, normalized_segments)
			end
			
			# Simplify this path in place by resolving literal or percent-encoded dot segments and repeated separators.
			#
			# @returns [Path | Nil] This path when changed, otherwise `nil`.
			def simplify!
				simplified = simplify
				return nil if simplified.equal?(self)
				
				@encoded = simplified.encoded
				@segments = simplified.segments
				
				return self
			end
			
			# Return a canonical path by resolving literal or percent-encoded dot segments and repeated separators.
			#
			# Absolute paths do not retain parent components above the root. Relative paths
			# retain leading parent components which cannot be resolved locally.
			#
			# @returns [Path] The simplified path, or this path if already canonical.
			def simplify
				segments = simplify_segments
				return self unless segments
				
				return self.class.new(nil, segments)
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
				
				segments = self.segments.dup
				
				# RFC2396 Section 5.2:
				# 6) a) All but the last segment of the base URI's path component is
				# copied to the buffer.  In other words, any characters after the
				# last (right-most) slash character, if any, are excluded.
				if pop and dot_segment(segments.last) != ".."
					segments.pop
				elsif segments.last == ""
					segments.pop
				end
				
				segments.concat(other.segments)
				
				if simplify
					simplify_segments!(segments)
				end
				
				return Path.new(nil, segments)
			end
			
			# Calculate this path relative to another path.
			#
			# @parameter from [String | Array(String) | Path] The source path.
			# @returns [Path] The relative path from `from` to this path.
			def relative(from)
				target_segments = self.segments
				from_segments = Path[from].segments
				
				# Remove the last component from 'from' to get the directory
				from_segments = from_segments[0...-1] if from_segments.size > 0
				
				# Find the common prefix
				common_length = 0
				[target_segments.size, from_segments.size].min.times do |i|
					break if target_segments[i] != from_segments[i]
					common_length = i + 1
				end
				
				# Calculate how many levels to go up
				up_levels = from_segments.size - common_length
				
				# Build the relative path segments
				relative_segments = [".."] * up_levels + target_segments[common_length..-1]
				
				return Path.new(nil, relative_segments)
			end
			
			private
			
			# Normalize one encoded path segment:
			def normalize_segment(segment)
				return segment.gsub(NORMALIZATION_PATTERN) do |character|
					byte = character.getbyte(0)
					
					if byte == 0
						raise ArgumentError, "Path segment contains NUL!"
					elsif byte == 0x25
						if character.bytesize == 1
							raise ArgumentError, "String contains malformed percent encoding!"
						end
						
						byte = character.byteslice(1, 2).to_i(16)
						if byte == 0
							raise ArgumentError, "Path segment contains NUL!"
						elsif unreserved_byte?(byte)
							byte.chr
						else
							character.upcase
						end
					else
						Encoding.escape(character)
					end
				end
			end
			
			# Whether the byte represents an unreserved URI character:
			def unreserved_byte?(byte)
				case byte
				when 0x30..0x39, 0x41..0x5A, 0x61..0x7A, 0x2D, 0x2E, 0x5F, 0x7E
					return true
				else
					return false
				end
			end
			
			# Identify dot segments, including percent-encoded spellings. RFC 3986 treats
			# percent-encoded unreserved characters as equivalent to their literal forms;
			# the WHATWG URL Standard explicitly recognizes `%2e`, `.%2e`, `%2e.`, and
			# `%2e%2e` as dot segments, case-insensitively.
			#
			# This classification does not decode or rewrite the stored encoded segment.
			# Paths retain their exact encoded representation unless a structural operation
			# removes the segment. General percent-encoding normalization, such as decoding
			# other unreserved characters or uppercasing hexadecimal digits, must be an
			# explicit operation rather than part of lossless path storage or simplification.
			def dot_segment(segment)
				return nil unless segment
				return "." if segment.match?(/\A(?:\.|%2e)\z/i)
				return ".." if segment.match?(/\A(?:\.|%2e){2}\z/i)
			end
			
			# Find the first encoded segment which requires simplification.
			def simplification_index(segments)
				absolute = segments.first == ""
				regular_segment = false
				last_index = segments.size - 1
				
				segments.each_with_index do |segment, index|
					dot = dot_segment(segment)
					
					if dot == "."
						return index
					elsif segment == ""
						# Leading and trailing empty components are significant.
						return index if index > 0 && index < last_index
					elsif dot == ".."
						# Absolute paths cannot retain parent components. Relative paths
						# can retain them only before the first regular component.
						return index if absolute || regular_segment
					else
						regular_segment = true
					end
				end
				
				return nil
			end
			
			# Return simplified encoded segments, or nil if they are already canonical.
			def simplify_segments
				segments = self.segments
				return nil unless start_index = simplification_index(segments)
				
				segments = segments.dup
				simplify_segments!(segments, start_index)
				
				return segments
			end
			
			# Simplify the given encoded segments in place.
			def simplify_segments!(segments, start_index = nil)
				start_index ||= simplification_index(segments)
				return nil unless start_index
				
				offset = start_index
				index = start_index
				last_index = segments.size - 1
				
				while index <= last_index
					segment = segments[index]
					dot = dot_segment(segment)
					
					if dot == "."
						# A trailing dot denotes a directory.
						if index == last_index
							segments[offset] = ""
							offset += 1
						end
					elsif segment == "" && index != last_index
						# Collapse repeated separators:
					elsif dot == ".." && offset > 0 && dot_segment(segments[offset - 1]) != ".."
						# Pop a component, but never pop the absolute-path root:
						offset -= 1 if segments[offset - 1] != ""
						
						# A trailing parent reference also denotes a directory.
						if index == last_index
							segments[offset] = ""
							offset += 1
						end
					else
						segments[offset] = segment if offset < index
						offset += 1
					end
					
					index += 1
				end
				
				if offset < segments.size
					segments[offset, segments.size - offset] = EMPTY_SEGMENTS
				end
				
				return segments
			end
		end
	end
end
