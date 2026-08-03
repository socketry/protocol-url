# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "../encoding"

module Protocol
	module URL
		module FormData
			# Builds nested form data from names and values.
			class Nested
				# The default maximum depth of a bracketed form name.
				MAXIMUM_DEPTH = 8
				
				# Initialize the nested form data.
				# @parameter maximum_depth [Integer | Nil] The maximum depth of a bracketed form name.
				def initialize(maximum_depth: MAXIMUM_DEPTH)
					@maximum_depth = maximum_depth
					@root = {}
				end
				
				# Add a form data value using its bracketed name.
				# @parameter name [String] The form data name.
				# @parameter value [Object] The form data value.
				# @returns [Nested] The receiver.
				def add(name, value)
					keys = Encoding.split(name)
					
					if keys.empty?
						raise ArgumentError, "Invalid form data name: #{name.inspect}!"
					end
					
					if @maximum_depth and keys.size > @maximum_depth
						raise RangeError, "Form data depth exceeded limit of #{@maximum_depth}!"
					end
					
					Encoding.assign(keys, value, @root)
					
					return self
				end
				
				# Convert the arguments to a nested hash.
				# @returns [Hash] The nested arguments.
				def to_h
					return @root
				end
			end
		end
	end
end
