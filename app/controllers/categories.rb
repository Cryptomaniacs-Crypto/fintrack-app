# frozen_string_literal: true

require_relative 'app'
require_relative '../services/list_categories'

module FinanceTracker
  # Category pages.
  class App < Roda
    route('categories') do |routing|
      require_login!(routing)
      auth_token = FinanceTracker::CurrentSession.new(session).auth_token

      routing.is do
        # GET /categories
        routing.get do
          categories = FinanceTracker::Services::ListCategories.new.call(auth_token: auth_token)
          view 'categories/index', locals: { categories: categories }
        rescue StandardError => e
          flash[:error] = "Could not load categories: #{e.message}"
          view 'categories/index', locals: { categories: [] }
        end
      end
    end
  end
end
