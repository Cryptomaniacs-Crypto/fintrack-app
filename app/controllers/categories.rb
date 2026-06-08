# frozen_string_literal: true

require_relative 'app'
require_relative '../forms/form_base'
require_relative '../forms/create_category'
require_relative '../services/list_categories'
require_relative '../services/create_category'
require_relative '../services/delete_category'

module FinanceTracker
  class App < Roda
    route('categories') do |routing|
      require_login!(routing)
      current_sess = FinanceTracker::CurrentSession.new(session)
      auth_token   = current_sess.auth_token

      # POST /categories/:id/delete
      routing.on String do |category_id|
        routing.is 'delete' do
          routing.post do
            FinanceTracker::Services::DeleteCategory.new(App.config)
              .call(auth_token: auth_token, category_id: category_id)
            flash[:notice] = 'Category deleted'
          rescue FinanceTracker::Services::DeleteCategory::ForbiddenError
            flash[:error] = 'You cannot delete this category'
          rescue StandardError => e
            flash[:error] = "Could not delete category: #{e.message}"
          ensure
            routing.redirect '/categories'
          end
        end
      end

      routing.is do
        # GET /categories
        routing.get do
          categories = FinanceTracker::Services::ListCategories.new(App.config).call(auth_token: auth_token)
          view 'categories/index', locals: { categories: categories, values: {} }
        rescue StandardError => e
          flash.now[:error] = "Could not load categories: #{e.message}"
          view 'categories/index', locals: { categories: [], values: {} }
        end

        # POST /categories
        routing.post do
          form_params = routing.params.transform_keys(&:to_s)
          validation  = FinanceTracker::Form::CreateCategory.call(form_params)

          if validation.failure?
            categories = FinanceTracker::Services::ListCategories.new(App.config).call(auth_token: auth_token)
            flash.now[:error] = FinanceTracker::Form.validation_errors(validation)
            next view 'categories/index', locals: { categories: categories, values: form_params }
          end

          FinanceTracker::Services::CreateCategory.new(App.config).call(
            auth_token: auth_token,
            name:       validation[:name]
          )
          flash[:notice] = 'Category added'
          routing.redirect '/categories'
        rescue StandardError => e
          flash[:error] = "Could not create category: #{e.message}"
          routing.redirect '/categories'
        end
      end
    end
  end
end
