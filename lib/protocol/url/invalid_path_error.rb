# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module URL
		# Raised when a URL path cannot be normalized safely.
		class InvalidPathError < ArgumentError
			# Initialize the invalid path error.
			# @parameter path [String] The invalid URL path.
			# @parameter reason [String] The reason the path is invalid.
			def initialize(path, reason)
				@path = path
				@reason = reason
				
				super("Invalid URL path #{path.inspect}: #{reason}")
			end
			
			# The invalid URL path.
			attr :path
			
			# The reason the path is invalid.
			attr :reason
		end
	end
end
