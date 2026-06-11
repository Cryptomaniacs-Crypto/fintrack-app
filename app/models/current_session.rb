# frozen_string_literal: true

require_relative 'account'

module FinanceTracker
  class CurrentSession
    class SecureSessionAdapter
      def initialize(session)
        @session = session
      end

      def get(key)
        SecureSession.get(@session, key)
      end

      def set(key, value)
        SecureSession.set(@session, key, value)
      end

      def delete(key)
        SecureSession.delete(@session, key)
      end
    end

    def initialize(session)
      @secure_session = SecureSessionAdapter.new(session)
    end

    def current_account
      Account.from_session(@secure_session.get(:current_account), @secure_session.get(:auth_token))
    end

    def auth_token
      @secure_session.get(:auth_token)
    end

    def auth_token=(token)
      @secure_session.set(:auth_token, token)
    end

    def account_api_token
      @secure_session.get(:account_api_token)
    end

    def account_api_token=(token)
      @secure_session.set(:account_api_token, token)
    end

    def current_account=(account)
      @secure_session.set(:current_account, account.account_info)
      @secure_session.set(:auth_token, account.auth_token)
      @secure_session.set(:account_api_token, account.account_api_token) if account.respond_to?(:account_api_token) && account.account_api_token
    end

    def account
      current_account
    end

    def delete
      @secure_session.delete(:current_account)
      @secure_session.delete(:auth_token)
      @secure_session.delete(:account_api_token)
    end
  end
end
