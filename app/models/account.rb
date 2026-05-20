# frozen_string_literal: true

module FinanceTracker
	# Simple model wrapper for account info and auth token.
	#
	# `account_info` should be a JSON-serializable Hash (as returned by the API).
	# `auth_token` is an opaque string used for authenticated service calls.
	class Account
		attr_reader :account_info, :auth_token

		def initialize(account_info = nil, auth_token = nil)
			@account_info = account_info || {}
			@auth_token = auth_token
		end

		def id
			fetch_field('id')
		end

		def username
			fetch_field('username')
		end

		def email
			fetch_field('email')
		end

		def system_roles
			Array(fetch_field('system_roles'))
		end

		def [](key)
			fetch_field(key)
		end

		private

		def fetch_field(key)
			return nil if @account_info.nil?

			str_key = key.to_s
			@account_info[str_key] || @account_info[str_key.to_sym]
		end
	end
end
