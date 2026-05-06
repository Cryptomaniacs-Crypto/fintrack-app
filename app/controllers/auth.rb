# frozen_string_literal: true

require_relative 'app'
require_relative '../services/authenticate_account'

module Tyto
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
            account = Fintrack::Services::AuthenticateAccount.new.call(username:, password:)
            session[:current_account] = account
            flash[:notice] = "Welcome back #{account['username']}!"
            routing.redirect '/account'
          rescue Fintrack::Services::AuthenticateAccount::AuthenticationFailed
            flash.now[:error] = 'Username and password did not match our records'
            response.status = 400
            view :login
          rescue Fintrack::Services::AuthenticateAccount::ApiUnavailable
            flash.now[:error] = 'Authentication service unavailable'
            response.status = 502
            view :login
          end
        end

        routing.get 'logout' do
          session.delete(:current_account)
          flash[:notice] = 'Logged out'
          routing.redirect '/auth/login'
        end
      end
    end
  end
end
