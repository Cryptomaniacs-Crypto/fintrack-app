# frozen_string_literal: true

require_relative 'app'

module FinTrack
  # Login / logout routes
  class App < Roda
    route('auth') do |routing|
      routing.is 'login' do
        # GET /auth/login
        routing.get do
          view :login
        end

        # POST /auth/login
        routing.post do
          username = routing.params['username'].to_s.strip
          password = routing.params['password'].to_s

          account = AuthenticateAccount.new(App.config).call(
            username: username, password: password
          )

          session[:current_account] = account
          flash[:notice] = "Welcome back, #{account['username']}!"
          routing.redirect '/'
        rescue AuthenticateAccount::UnauthorizedError => e
          App.logger.warn "LOGIN FAILED: #{e.message}"
          flash.now[:error] = 'Username and password did not match our records'
          response.status = 401
          view :login
        rescue StandardError => e
          App.logger.error "LOGIN ERROR: #{e.inspect}"
          flash.now[:error] = 'Could not reach authentication service'
          response.status = 500
          view :login
        end
      end

      # GET /auth/logout
      routing.is 'logout' do
        routing.get do
          session[:current_account] = nil
          flash[:notice] = "You've been logged out"
          routing.redirect '/auth/login'
        end
      end
    end
  end
end
