# frozen_string_literal: true

require 'roda'
require 'slim'

require_relative '../../config/environments'
require_relative '../services/api_client'
require_relative '../services/authenticate_account'

module FinTrack
  # Base web controller — sets layout, session, and dispatches to other route files.
  class App < Roda
    plugin :render, engine: 'slim', views: 'app/presentation/views'
    plugin :assets, css: 'style.css', path: 'app/presentation/assets'
    plugin :public, root: 'app/presentation/public'
    plugin :multi_route
    plugin :flash
    plugin :all_verbs
    plugin :halt

    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_account = session[:current_account]

      routing.public
      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        view 'home', locals: { current_account: @current_account }
      end
    end

    private

    def require_login!(routing)
      return if @current_account

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end
  end
end

require_relative 'auth'
require_relative 'account'
