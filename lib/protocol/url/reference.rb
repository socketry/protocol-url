# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "encoding"
require_relative "relative"

module Protocol
	module URL
		# Represents a "Hypertext Reference", which may include a path, query string, fragment, and user parameters.
		#
		# This class is designed to be easy to manipulate and combine URL references, following the rules specified in RFC2396, while supporting standard URL encoded parameters. In other words, it gives extended meaning to query strings by allowing user parameters to be specified as a hash.
		class Reference < Relative
			include Comparable
			
			# Generate a reference from a path and user parameters. The path may contain a `#fragment` or `?query=parameters`.
			def self.parse(value, parameters = nil)
				base, fragment = value.split("#", 2)
				path, query = base.split("?", 2)
				
				self.new(path, query, fragment, parameters)
			end
			
			# Initialize the reference.
			#
			# @parameter parameters [Hash | Nil] User supplied parameters that will be appended to the query part.
			def initialize(path = "/", query = nil, fragment = nil, parameters = nil)
				super(path, query, fragment)
				@parameters = parameters
			end
			
			# @attribute [Hash] User supplied parameters that will be appended to the query part.
			attr :parameters
			
			# Freeze the reference.
			#
			#	@returns [Reference] The frozen reference.
			def freeze
				return self if frozen?
				
				@parameters.freeze
				
				super
			end
			
			# Implicit conversion to an array.
			#
			# @returns [Array] The reference as an array, `[path, query, fragment, parameters]`.
			def to_ary
				[@path, @query, @fragment, @parameters]
			end
			
			# Compare two references.
			#
			# @parameter other [Reference] The other reference to compare.
			# @returns [Integer] -1, 0, 1 if the reference is less than, equal to, or greater than the other reference.
			def <=> other
				to_ary <=> other.to_ary
			end
			
			# Type-cast a reference.
			#
			# @parameter reference [Reference | String] The reference to type-cast.
			# @returns [Reference] The type-casted reference.
			def self.[] reference
				if reference.is_a? self
					return reference
				else
					return self.parse(reference)
				end
			end
			
			# @returns [Boolean] Whether the reference has parameters.
			def parameters?
				@parameters and !@parameters.empty?
			end
			
			# Parse the query string into parameters and merge with existing parameters.
			#
			# Afterwards, the `query` attribute will be cleared.
			#
			# @returns [Hash] The merged parameters.
			def parse_query!(encoding = Encoding)
				if @query and !@query.empty?
					parsed = encoding.decode(@query)
					
					if @parameters
						@parameters = @parameters.merge(parsed)
					else
						@parameters = parsed
					end
					
					@query = nil
				end
				
				return @parameters
			end
			
			# @returns [Boolean] Whether the reference has a query string.
			def query?
				@query and !@query.empty?
			end
			
			# @returns [Boolean] Whether the reference has a fragment.
			def fragment?
				@fragment and !@fragment.empty?
			end
			
			# Append the reference to the given buffer.
			private def append_query(buffer = String.new)
				if @query and !@query.empty?
					buffer << "?" << @query
					buffer << "&" << Encoding.encode(@parameters) if parameters?
				elsif parameters?
					buffer << "?" << Encoding.encode(@parameters)
				end
				
				return buffer
			end
			
			# Merges two references as specified by RFC2396, similar to `URI.join`.
			def + other
				other = self.class[other]
				
				self.class.new(
					expand_path(self.path, other.path, true),
					other.query,
					other.fragment,
					other.parameters,
				)
			end
			
			# Just the base path, without any query string, parameters or fragment.
			def base
				self.class.new(@path, nil, nil, nil)
			end
			
			# Update the reference with the given path, parameters and fragment.
			#
			# @parameter path [String] Append the string to this reference similar to `File.join`.
			# @parameter parameters [Hash] Append the parameters to this reference.
			# @parameter fragment [String] Set the fragment to this value.
			# @parameter pop [Boolean] If the path contains a trailing filename, pop the last component of the path before appending the new path.
			# @parameter merge [Boolean] If the parameters are specified, merge them with the existing parameters, otherwise replace them (including query string).
			def with(path: nil, parameters: false, fragment: @fragment, pop: false, merge: true)
				if merge
					# Merge mode: combine new parameters with existing, keep query:
					# parameters = (@parameters || {}).merge(parameters || {})
					if @parameters
						if parameters
							parameters = @parameters.merge(parameters)
						else
							parameters = @parameters
						end
					elsif !parameters
						parameters = @parameters
					end
					
					query = @query
				else
					# Replace mode: use new parameters if provided, clear query when replacing:
					if parameters == false
						# No new parameters provided, keep existing:
						parameters = @parameters
						query = @query
					else
						# New parameters provided, replace and clear query:
						# parameters = parameters
						query = nil
					end
				end
				
				if path
					path = expand_path(@path, path, pop)
				else
					path = @path
				end
				
				self.class.new(path, query, fragment, parameters)
			end
		end
	end
end
