# frozen_string_literal: true

require_relative 'app'
require_relative '../services/authenticate_account'

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
            account = FinanceTracker::Services::AuthenticateAccount.new.call(username:, password:)
            puts "DEBUG: Authenticated account = #{account.inspect}"
            session['current_account'] = account
            puts "DEBUG: Session after login = #{session.inspect}"
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

        routing.get 'register' do
          view :register
        end

        routing.post 'register' do
          flash.now[:error] = 'Registration is not available in this client'
          response.status = 501
          view :register
        end

        routing.get 'logout' do
          session.delete('current_account')
          flash[:notice] = 'Logged out'
          routing.redirect '/auth/login'
        end
      end
    end
  end
end
