# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "../encoding"
require_relative "../error"

module Protocol
	module URL
		module FormData
			# Builds nested form data from names and values.
			class Nested
				# The bracketed form name depth limit.
				DEPTH_LIMIT = 8
				
				# Initialize the nested form data.
				# @parameter depth_limit [Integer | Nil] The bracketed form name depth limit.
				def initialize(depth_limit: DEPTH_LIMIT)
					@depth_limit = depth_limit
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
					
					if @depth_limit and keys.size > @depth_limit
						raise LimitError, "Form data depth exceeded limit of #{@depth_limit}!"
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
