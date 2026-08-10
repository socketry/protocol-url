# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module URL
		# Raised when a URL path cannot be split or converted safely.
		class InvalidPathError < ArgumentError
			# Initialize the invalid path error.
			# @parameter path [String] The invalid URL path.
			# @parameter operation [String] The operation that could not be completed.
			# @parameter reason [String] The reason the path is invalid.
			def initialize(path, operation, reason)
				@path = path
				@operation = operation
				@reason = reason
				
				super("URL path #{path.inspect} could not be #{operation} because #{reason}!")
			end
			
			# The invalid URL path.
			attr :path
			
			# The operation that could not be completed.
			attr :operation
			
			# The reason the path is invalid.
			attr :reason
		end
	end
end
