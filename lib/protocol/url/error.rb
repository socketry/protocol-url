# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module URL
		# Raised when URL processing exceeds a configured limit.
		class LimitError < StandardError
		end
	end
end
