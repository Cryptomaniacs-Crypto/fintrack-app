# frozen_string_literal: true

require_relative 'app'
require_relative '../services/list_categories'

module FinanceTracker
  # Category pages.
  class App < Roda
    route('categories') do |routing|
      require_login!(routing)

      routing.is do
        # GET /categories
        routing.get do
          categories = FinanceTracker::Services::ListCategories.new.call
          view 'categories/index', locals: { categories: categories }
        rescue StandardError => e
          flash[:error] = "Could not load categories: #{e.message}"
          view 'categories/index', locals: { categories: [] }
        end
      end
    end
  end
end
