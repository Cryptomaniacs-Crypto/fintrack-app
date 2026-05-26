# frozen_string_literal: true

module FinanceTracker
	# Parser model that wraps Account API envelopes.
	# Use Account.from_api(envelope_hash) — `new` is private so the named
	# factory is the only entry point and the parsing role stays explicit.
	class Account
		attr_reader :account_info, :auth_token

		def self.from_api(envelope)
			new(envelope)
		end

		def self.from_auth(envelope)
			new(envelope)
		end

		def self.from_session(account_info, auth_token = nil)
			envelope = {
				'attributes' => account_info,
				'auth_token' => auth_token
			}
			new(envelope)
		end

		# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
		def initialize(envelope)
			root = envelope.is_a?(Hash) ? envelope : {}
			data = root['data'] || root[:data] || root
			data = {} unless data.is_a?(Hash)

			attrs = data['attributes'] || data[:attributes] || root['attributes'] || root[:attributes] || data
			attrs = {} unless attrs.is_a?(Hash)

			included = root['included'] || root[:included] || data['include'] || data[:include] || root['include'] || root[:include] || {}
			included = {} unless included.is_a?(Hash)

			meta = root['meta'] || root[:meta] || {}
			meta = {} unless meta.is_a?(Hash)

			roles =
				if attrs.key?('system_roles') || attrs.key?(:system_roles)
					Array(attrs['system_roles'] || attrs[:system_roles])
				elsif included.key?('system_roles') || included.key?(:system_roles)
					Array(included['system_roles'] || included[:system_roles]).map do |role|
						role.is_a?(Hash) ? (role['name'] || role[:name]) : role
					end
				else
					[]
				end
			roles = roles.compact.map(&:to_s)

			@auth_token =
				attrs['auth_token'] || attrs[:auth_token] ||
				meta['auth_token'] || meta[:auth_token] ||
				root['auth_token'] || root[:auth_token]

			@account_info = attrs.dup
			@account_info.delete('auth_token')
			@account_info.delete(:auth_token)
			@account_info['system_roles'] = roles
		end
		# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

		def id = fetch_field('id')
		def username = fetch_field('username')
		def email = fetch_field('email')
		def system_roles = Array(fetch_field('system_roles'))

		def admin?
			system_roles.include?('admin')
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

		private_class_method :new
	end
end
