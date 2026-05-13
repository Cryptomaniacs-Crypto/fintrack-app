# frozen_string_literal: true

require_relative 'app'

module FinTrack
  # Account overview page
  class App < Roda
    route('account') do |routing|
      require_login!(routing)

      # GET /account
      routing.is do
        routing.get do
          view :account, locals: { account: @current_account }
        end
      end
    end
  end
end
