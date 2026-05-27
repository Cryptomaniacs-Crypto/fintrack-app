# frozen_string_literal: true

require_relative 'app'
require_relative '../forms/form_base'
require_relative '../forms/login_credentials'
require_relative '../forms/registration'
require_relative '../services/authenticate_account'
require_relative '../services/create_account'
require_relative '../lib/secure_session'

module FinanceTracker
  class App < Roda
    route('auth') do |routing|
      routing.on do
        routing.get 'login' do
          view :login
        end

        routing.post 'login' do
          validation = FinanceTracker::Form::LoginCredentials.call(routing.params)
          if validation.failure?
            flash.now[:error] = FinanceTracker::Form.validation_errors(validation)
            response.status = 400
            next view(:login)
          end

          begin
            account = FinanceTracker::Services::AuthenticateAccount.new(App.config).call(
              username: validation[:username], password: validation[:password]
            )
            SecureSession.set(session, 'current_account', account.to_h)
            flash[:notice] = "Welcome back #{account['username']}!"
            routing.redirect '/'
          rescue FinanceTracker::Services::AuthenticateAccount::UnauthorizedError
            flash.now[:error] = 'Username and password did not match our records'
            response.status = 401
            view :login
          rescue StandardError
            flash.now[:error] = 'Authentication service unavailable'
            response.status = 502
            view :login
          end
        end

        routing.get 'register' do
          view :register
        end

        routing.post 'register' do
          validation = FinanceTracker::Form::Registration.call(routing.params)
          if validation.failure?
            flash.now[:error] = FinanceTracker::Form.validation_errors(validation)
            response.status = 400
            next view(:register)
          end

          begin
            FinanceTracker::Services::CreateAccount.new(App.config).call(
              email: validation[:email],
              username: validation[:username],
              password: validation[:password]
            )
            flash[:notice] = 'Account created. Please log in.'
            routing.redirect '/auth/login'
          rescue FinanceTracker::Services::CreateAccount::InvalidAccount => e
            flash.now[:error] = e.message.empty? ? 'Could not create account' : e.message
            response.status = 400
            view :register
          rescue StandardError
            flash.now[:error] = 'Registration service unavailable'
            response.status = 502
            view :register
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
