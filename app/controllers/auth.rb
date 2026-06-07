# frozen_string_literal: true

require_relative 'app'
require_relative '../services/authenticate_account'
require_relative '../services/verify_registration'
require_relative '../services/authorize_google_account'
require 'securerandom'
require 'uri'
require_relative '../lib/registration_token'
require_relative '../lib/secure_session'
require_relative '../models/current_session'

module FinanceTracker
  class App < Roda
    # Build the Google OAuth 2.0 authorization-code URL. `state` is an anti-CSRF nonce
    # echoed back to /auth/sso_callback and verified there.
    def google_oauth_url(config, state)
      query = URI.encode_www_form(
        client_id: config.GOOGLE_CLIENT_ID,
        redirect_uri: config.GOOGLE_REDIRECT_URI,
        response_type: 'code',
        scope: config.GOOGLE_SCOPE,
        state: state,
        prompt: 'select_account'
      )

      "#{config.GOOGLE_OAUTH_URL}?#{query}"
    end

    # Mint (once per session) + stash the CSRF state, returning the authorize URL
    # for the "Sign in with Google" button on every login render.
    def sso_login_url(session)
      state = (session['sso_state'] ||= SecureRandom.hex(16))
      google_oauth_url(App.config, state)
    end

    route('auth') do |routing|
      routing.on do
        routing.get 'login' do
          routing.redirect "/account/#{@current_account.username}" if @current_account&.username
          view :login, locals: { google_oauth_url: sso_login_url(session) }
        end

        routing.post 'login' do
          username = routing.params['username'].to_s.strip
          password = routing.params['password'].to_s

          begin
            result = FinanceTracker::Services::AuthenticateAccount.new(App.config).call(username:, password:)
            account_info = result.is_a?(Hash) ? (result[:account] || result['account'] || result) : {}
            auth_token = result.is_a?(Hash) ? (result[:auth_token] || result['auth_token']) : nil
            account_api_token = result.is_a?(Hash) ? (result[:account_api_token] || result['account_api_token']) : nil

            SecureSession.set(session, 'current_account', account_info)
            SecureSession.set(session, 'auth_token', auth_token) if auth_token
            SecureSession.set(session, 'account_api_token', account_api_token) if account_api_token

            flash[:notice] = "Welcome back #{account_info['username']}!"
            routing.redirect "/account/#{account_info['username']}"
          rescue FinanceTracker::Services::AuthenticateAccount::UnauthorizedError
            flash.now[:error] = 'Username and password did not match our records'
            response.status = 400
            view :login, locals: { google_oauth_url: sso_login_url(session) }
          rescue StandardError
            flash.now[:error] = 'Authentication service unavailable'
            response.status = 502
            view :login, locals: { google_oauth_url: sso_login_url(session) }
          end
        end

        routing.is 'sso_callback' do
          routing.get do
            expected = session.delete('sso_state')
            unless expected && routing.params['state'] == expected
              flash[:error] = 'Sign-in session expired or could not be verified -- please try again'
              routing.redirect '/auth/login'
            end

            begin
              authorized = FinanceTracker::Services::AuthorizeGoogleAccount.new(App.config).call(routing.params['code'])
              account = FinanceTracker::Account.from_api(authorized)
              current_session = FinanceTracker::CurrentSession.new(session)
              current_session.current_account = account
              current_session.auth_token = account.auth_token if account.auth_token
              current_session.account_api_token = account.account_api_token if account.account_api_token

              username = account.username || account['username']
              flash[:notice] = "Welcome #{username}!"
              routing.redirect "/account/#{username}"
            rescue FinanceTracker::Services::AuthorizeGoogleAccount::AuthorizeError
              flash[:error] = 'Could not sign in with Google'
              response.status = 403
              routing.redirect '/auth/login'
            rescue StandardError => e
              App.logger.error "SSO LOGIN ERROR: #{e.inspect}"
              flash[:error] = 'Unexpected error during Google sign-in'
              response.status = 500
              routing.redirect '/auth/login'
            end
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
              routing.redirect "/account/#{@current_account.username}" if @current_account&.username
              view :register
            end

            routing.post do
              FinanceTracker::Services::VerifyRegistration.new(App.config).call(
                email: routing.params['email'].to_s.strip,
                username: routing.params['username'].to_s.strip
              )
              flash[:notice] = 'Check your email for a verification link'
              routing.redirect '/auth/login'
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
          SecureSession.delete(session, 'auth_token')
          SecureSession.delete(session, 'account_api_token')
          flash[:notice] = 'Logged out'
          routing.redirect '/auth/login'
        end
      end
    end
  end
end
