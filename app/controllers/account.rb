# frozen_string_literal: true

require_relative 'app'
require_relative '../services/fintrack_api'
require_relative '../services/get_account'
require_relative '../services/create_account'
require_relative '../services/assign_system_role'
require_relative '../services/revoke_system_role'
require_relative '../lib/registration_token'
require_relative '../lib/secure_session'

module FinanceTracker
  # Account pages and account-level actions for the web app.
  class App < Roda
    route('account') do |routing|
      routing.is do
        require_login!(routing)

        routing.get do
          return routing.redirect '/auth/login' unless @current_account && @current_account['username']

          routing.redirect "/account/#{@current_account['username']}"
        end
      end

      routing.on String do |username_or_token|
        routing.post do
          token = RegistrationToken.load(username_or_token)
          password = routing.params['password'].to_s
          password_confirm = routing.params['password_confirm'].to_s

          if password.empty? || password != password_confirm
            flash[:error] = 'Passwords did not match'
            routing.redirect "/auth/register/#{username_or_token}"
          end

          FinanceTracker::Services::CreateAccount.new(App.config).call(
            email: token.email,
            username: token.username,
            password: password
          )
          flash[:notice] = 'Account created -- please log in'
          routing.redirect '/auth/login'
        rescue RegistrationToken::InvalidTokenError
          flash[:error] = 'Verification link is invalid or expired'
          routing.redirect '/auth/register'
        rescue FinanceTracker::Services::CreateAccount::InvalidAccount => e
          flash[:error] = e.message.empty? ? 'Could not create account' : e.message
          routing.redirect '/auth/register'
        rescue StandardError => e
          App.logger.error "ERROR CREATING ACCOUNT: #{e.inspect}"
          flash[:error] = 'Could not create account'
          routing.redirect '/auth/register'
        end

        require_login!(routing)
        username = username_or_token

        unless username == @current_account['username'] || system_admin?(@current_account)
          flash[:error] = 'You can only view your own account page'
          return routing.redirect '/auth/login' unless @current_account && @current_account['username']

          routing.redirect "/account/#{@current_account['username']}"
        end

        routing.on 'system_roles' do
          routing.on String do |role_name|
            unless system_admin?(@current_account)
              flash[:error] = 'Only admins can manage system roles'
              routing.redirect "/account/#{@current_account['username']}"
            end

            routing.put do
              FinanceTracker::Services::AssignSystemRole.new.call(
                current_account_id: @current_account['id'],
                target_username: username,
                role_name: role_name
              )
              flash[:notice] = "Granted #{role_name} to #{username}"
              routing.redirect "/account/#{username}"
            rescue StandardError => e
              flash[:error] = "Could not grant role: #{e.message}"
              routing.redirect "/account/#{username}"
            end

            routing.delete do
              FinanceTracker::Services::RevokeSystemRole.new.call(
                current_account_id: @current_account['id'],
                target_username: username,
                role_name: role_name
              )
              flash[:notice] = "Revoked #{role_name} from #{username}"
              routing.redirect "/account/#{username}"
            rescue StandardError => e
              flash[:error] = "Could not revoke role: #{e.message}"
              routing.redirect "/account/#{username}"
            end
          end
        end

        routing.is do
          routing.get do
            target_account = load_account(username)
            transactions =
              if username == @current_account['username']
                FinanceTracker::Services::FintrackApi.new.list_transactions
              else
                []
              end

            view :account, locals: { account: target_account, viewer: @current_account, transactions: transactions }
          rescue FinanceTracker::Services::ApiClient::ApiError => e
            flash[:error] = "Could not load account: #{e.message}"
            return routing.redirect '/auth/login' unless @current_account && @current_account['username']

            routing.redirect "/account/#{@current_account['username']}"
          end

          routing.delete do
            SecureSession.delete(session, 'current_account')
            flash[:notice] = 'Logged out'
            routing.redirect '/auth/login'
          end
        end
      end
    end

    private

    def load_account(username)
      return @current_account if username == @current_account['username']

      raise StandardError, 'Not authorized' unless system_admin?(@current_account)

      FinanceTracker::Services::GetAccount.new.call(username, current_account_id: @current_account['id'])
    end
  end
end
