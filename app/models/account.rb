# frozen_string_literal: true

module FinanceTracker
	# Parser model that wraps Account API envelopes.
	# Use Account.from_api(envelope_hash) — `new` is private so the named
	# factory is the only entry point and the parsing role stays explicit.
	class Account
		attr_reader :account_info, :auth_token, :account_api_token

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

			@account_api_token =
				attrs['account_api_token'] || attrs[:account_api_token] ||
				meta['account_api_token'] || meta[:account_api_token] ||
				root['account_api_token'] || root[:account_api_token]

			@capabilities =
				root['capabilities'] || root[:capabilities] ||
				data['capabilities'] || data[:capabilities] ||
				attrs['capabilities'] || attrs[:capabilities] || {}
			@capabilities = {} unless @capabilities.is_a?(Hash)

			@policies =
				root['policies'] || root[:policies] ||
				data['policies'] || data[:policies] ||
				attrs['policies'] || attrs[:policies] || {}
			@policies = {} unless @policies.is_a?(Hash)

			@account_info = attrs.dup
			@account_info.delete('auth_token')
			@account_info.delete(:auth_token)
			@account_info['system_roles'] = roles
			@account_info['capabilities'] = @capabilities
			@account_info['policies'] = @policies
		end
		# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

		def id = fetch_field('id')
		def username = fetch_field('username')
		def email = fetch_field('email')
		def system_roles = Array(fetch_field('system_roles'))
		def capabilities = @capabilities
		def policies = @policies

		def admin?
			@capabilities['is_admin'] || @capabilities[:is_admin] || system_roles.include?('admin')
		end

		def can_manage_system_roles?
			@capabilities['can_manage_system_roles'] || @capabilities[:can_manage_system_roles] || false
		end

		def can_create_wallet?
			@capabilities['can_create_wallet'] || @capabilities[:can_create_wallet] || false
		end

		def can_create_transaction?
			@capabilities['can_create_transaction'] || @capabilities[:can_create_transaction] || false
		end

		def [](key)
			fetch_field(key)
		end

		def dig(*keys)
			keys.reduce(@account_info) do |value, key|
				next nil unless value.respond_to?(:[])

				value[key.to_s] || value[key.to_sym]
			end
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
