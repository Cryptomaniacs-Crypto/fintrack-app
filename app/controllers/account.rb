# frozen_string_literal: true

require_relative 'app'
require_relative '../services/fintrack_api'

module Tyto
  class App < Roda
    route('account') do |routing|
      require_login!(routing)

      routing.get do
        api = Fintrack::Services::FintrackApi.new
        transactions = api.list_transactions

        view :account, locals: { account: @current_account, transactions: transactions }
      end
    end
  end
end
