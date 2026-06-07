# frozen_string_literal: true

require_relative 'app'
require_relative '../services/list_accounts'
require_relative '../models/current_session'

module FinanceTracker
  class App < Roda
    route('admin') do |routing|
      require_login!(routing)

      unless system_admin?(@current_account)
        flash[:error] = 'Only admins can access this area'
        routing.redirect '/'
      end

      routing.on 'accounts' do
        # GET /admin/accounts
        routing.get do
          current_sess = FinanceTracker::CurrentSession.new(session)
          auth_token = current_sess.auth_token

          role_filter = routing.params['role']
          sort = routing.params['sort']

          accounts = FinanceTracker::Services::ListAccounts.new(App.config).call(
            auth_token: auth_token,
            role: role_filter,
            sort: sort
          )

          view 'admin/accounts_index', locals: {
            accounts: accounts,
            role_filter: role_filter,
            sort: sort
          }
        rescue FinanceTracker::Services::ListAccounts::ForbiddenError
          flash[:error] = 'Only admins can view the members list'
          routing.redirect '/'
        rescue StandardError => e
          App.logger.error "MEMBERS PAGE ERROR: #{e.inspect}"
          flash[:error] = 'Could not load the members list'
          routing.redirect '/'
        end
      end
    end
  end
end
