# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "nested"

module Protocol
	module URL
		# @namespace
		module FormData
			# Incrementally parses `application/x-www-form-urlencoded` form data.
			class Parser
				CONTENT_TYPE = "application/x-www-form-urlencoded"
				
				# The default maximum encoded body size.
				MAXIMUM_TOTAL_SIZE = 2 * 1024 * 1024
				
				# The default maximum number of form pairs.
				MAXIMUM_PAIR_COUNT = 1024
				
				# Initialize the form data parser.
				# @parameter maximum_total_size [Integer | Nil] The maximum encoded body size.
				# @parameter maximum_pair_count [Integer | Nil] The maximum number of form pairs.
				# @parameter maximum_depth [Integer | Nil] The maximum depth of a bracketed form name.
				def initialize(maximum_total_size: MAXIMUM_TOTAL_SIZE, maximum_pair_count: MAXIMUM_PAIR_COUNT, maximum_depth: Nested::MAXIMUM_DEPTH)
					@maximum_total_size = maximum_total_size
					@maximum_pair_count = maximum_pair_count
					@maximum_depth = maximum_depth
				end
				
				# Parse URL-encoded form data into a nested hash.
				#
				# When a block is given, each decoded value is passed through the block before assignment. The value returned by the block is assigned to the result.
				#
				# @parameter body [Object] A readable body which yields chunks from `#read`.
				# @parameter result [Object] The result to populate. It must support `#add` and `#to_h`.
				# @yields {|name, value| ...} Each decoded form pair before assignment.
				# @returns [Hash] The nested form data.
				def parse(body, result = make_result)
					each(body) do |name, value|
						value = yield(name, value) if block_given?
						result.add(name, value)
					end
					
					return result.to_h
				end
				
				# Incrementally enumerate URL-encoded form data as ordered name/value pairs.
				# @parameter body [Object] A readable body which yields chunks from `#read`.
				# @yields {|name, value| ...} Each decoded form pair.
				# @returns [Enumerator | Boolean] An enumerator without a block, or true when complete.
				def each(body)
					return to_enum(__method__, body) unless block_given?
					
					buffer = String.new.b
					total_size = 0
					pair_count = 0
					
					while chunk = body.read
						break if chunk.empty?
						
						total_size += chunk.bytesize
						check_limit(:total_size, total_size, @maximum_total_size)
						buffer << chunk
						
						while separator = buffer.index("&")
							assignment = buffer.slice!(0, separator + 1)
							assignment.chop!
							
							unless assignment.empty?
								pair_count += 1
								check_limit(:pair_count, pair_count, @maximum_pair_count)
								yield_pair(assignment) {|name, value| yield name, value}
							end
						end
					end
					
					unless buffer.empty?
						pair_count += 1
						check_limit(:pair_count, pair_count, @maximum_pair_count)
						yield_pair(buffer) {|name, value| yield name, value}
					end
					
					return true
				end
				
				private
				
				def make_result
					return Nested.new(maximum_depth: @maximum_depth)
				end
				
				def yield_pair(assignment)
					name, value = assignment.split("=", 2)
					
					if value
						value = decode_component(value)
					end
					
					yield decode_component(name), value
				end
				
				def decode_component(component)
					return Encoding.unescape(component.tr("+", " "))
				end
				
				def check_limit(name, value, maximum)
					if maximum and value > maximum
						raise RangeError, "Form data #{name} exceeded limit of #{maximum}!"
					end
				end
			end
		end
	end
end
