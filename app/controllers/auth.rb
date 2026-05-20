# frozen_string_literal: true

require_relative 'app'
require_relative '../services/authenticate_account'
require_relative '../services/verify_registration'
require_relative '../lib/registration_token'
require_relative '../lib/secure_session'

module FinanceTracker
  class App < Roda
    route('auth') do |routing|
      routing.on do
        routing.get 'login' do
          view :login
        end

        routing.post 'login' do
          username = routing.params['username'].to_s.strip
          password = routing.params['password'].to_s

          begin
            account = FinanceTracker::Services::AuthenticateAccount.new(App.config).call(username:, password:)
            SecureSession.set(session, 'current_account', account)
            flash[:notice] = "Welcome back #{account['username']}!"
            routing.redirect '/'
          rescue FinanceTracker::Services::AuthenticateAccount::UnauthorizedError
            flash.now[:error] = 'Username and password did not match our records'
            response.status = 400
            view :login
          rescue StandardError
            flash.now[:error] = 'Authentication service unavailable'
            response.status = 502
            view :login
          end
        end

        routing.on 'register' do
          routing.is String do |registration_token|
            token = RegistrationToken.load(registration_token)
            view :register_confirm, locals: {
              registration_token: registration_token,
              email: token.email,
              username: token.username
            }
          rescue RegistrationToken::InvalidTokenError
            flash[:error] = 'Verification link is invalid or expired'
            routing.redirect '/auth/register'
          end

          routing.is do
            routing.get do
              view :register
            end

            routing.post do
              FinanceTracker::Services::VerifyRegistration.new(App.config).call(
                email: routing.params['email'].to_s.strip,
                username: routing.params['username'].to_s.strip
              )
              flash[:notice] = 'Check your email for a verification link'
              routing.redirect '/'
            rescue FinanceTracker::Services::VerifyRegistration::VerificationError => e
              flash[:error] = e.message
              routing.redirect '/auth/register'
            rescue FinanceTracker::Services::VerifyRegistration::ApiServerError => e
              App.logger.warn "API server error: #{e.inspect}"
              flash[:error] = 'Our servers are not responding -- please try later'
              routing.redirect '/auth/register'
            rescue StandardError => e
              App.logger.error "ERROR REGISTERING: #{e.inspect}"
              flash[:error] = 'Could not start registration'
              routing.redirect '/auth/register'
            end
          end
        end

        routing.get 'logout' do
          SecureSession.delete(session, 'current_account')
          flash[:notice] = 'Logged out'
          routing.redirect '/auth/login'
        end
      end
    end
  end
end
