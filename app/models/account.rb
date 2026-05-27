# frozen_string_literal: true

module FinanceTracker
  class Account
    def self.from_api(account_info)
      return nil if account_info.nil?
      return nil if account_info.respond_to?(:empty?) && account_info.empty?

      new(account_info)
    end

    def initialize(account_info)
      @account_info = account_info || {}
    end

    def [](key)
      return id if key.to_s == 'id'
      return username if key.to_s == 'username'
      return email if key.to_s == 'email'
      return system_roles if key.to_s == 'system_roles'
      return policies if key.to_s == 'policies'
      return capabilities if key.to_s == 'capabilities'

      @account_info[key] || @account_info[key.to_sym]
    end

    def dig(*keys)
      keys.reduce(@account_info) do |value, key|
        next nil unless value.respond_to?(:[])

        value[key] || value[key.to_s] || value[key.to_sym]
      end
    end

    def to_h
      @account_info
    end

    def id
      attributes&.dig('id') || attributes&.dig(:id)
    end

    def username
      attributes&.dig('username') || attributes&.dig(:username)
    end

    def email
      attributes&.dig('email') || attributes&.dig(:email)
    end

    def system_roles
      raw = dig('included', 'system_roles') ||
            dig(:included, :system_roles) ||
            dig('system_roles') ||
            dig(:system_roles)
      Array(raw).map do |role|
        role.is_a?(Hash) ? role['name'] || role[:name] : role.to_s
      end
    end

    def policies
      dig('policies') || dig(:policies) || {}
    end

    def capabilities
      dig('capabilities') || dig(:capabilities) || {}
    end

    def admin?
      capabilities['is_admin'] || capabilities[:is_admin] || false
    end

    def can_manage_system_roles?
      capabilities['can_manage_system_roles'] || capabilities[:can_manage_system_roles] || false
    end

    def can_create_wallet?
      capabilities['can_create_wallet'] || capabilities[:can_create_wallet] || false
    end

    def can_create_transaction?
      capabilities['can_create_transaction'] || capabilities[:can_create_transaction] || false
    end

    def auth_token
      dig('auth_token') || dig(:auth_token) || id
    end

    private

    def attributes
      return @account_info unless @account_info.is_a?(Hash)

      if @account_info['data'].is_a?(Hash)
        @account_info['data']['attributes'] || @account_info['data']
      elsif @account_info['attributes'].is_a?(Hash)
        @account_info['attributes']
      else
        @account_info
      end
    end
  end
end
