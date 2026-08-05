# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "nested"
require_relative "../error"

module Protocol
	module URL
		# @namespace
		module FormData
			# Incrementally parses `application/x-www-form-urlencoded` form data.
			class Parser
				MEDIA_TYPE = "application/x-www-form-urlencoded"
				
				# The encoded body size limit.
				SIZE_LIMIT = 2 * 1024 * 1024
				
				# The form pair count limit.
				PAIR_COUNT_LIMIT = 1024
				
				# Initialize the form data parser.
				# @parameter size_limit [Integer | Nil] The encoded body size limit.
				# @parameter pair_count_limit [Integer | Nil] The form pair count limit.
				# @parameter depth_limit [Integer | Nil] The bracketed form name depth limit.
				def initialize(size_limit: SIZE_LIMIT, pair_count_limit: PAIR_COUNT_LIMIT, depth_limit: Nested::DEPTH_LIMIT)
					@size_limit = size_limit
					@pair_count_limit = pair_count_limit
					@depth_limit = depth_limit
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
					size = 0
					pair_count = 0
					
					while chunk = body.read
						break if chunk.empty?
						
						size += chunk.bytesize
						check_limit(:size, size, @size_limit)
						buffer << chunk
						
						while separator = buffer.index("&")
							assignment = buffer.slice!(0, separator + 1)
							assignment.chop!
							
							unless assignment.empty?
								pair_count += 1
								check_limit(:pair_count, pair_count, @pair_count_limit)
								yield_pair(assignment) {|name, value| yield name, value}
							end
						end
					end
					
					unless buffer.empty?
						pair_count += 1
						check_limit(:pair_count, pair_count, @pair_count_limit)
						yield_pair(buffer) {|name, value| yield name, value}
					end
					
					return true
				end
				
				private
				
				def make_result
					return Nested.new(depth_limit: @depth_limit)
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
				
				def check_limit(name, value, limit)
					if limit and value > limit
						raise LimitError, "Form data #{name} exceeded limit of #{limit}!"
					end
				end
			end
		end
	end
end
