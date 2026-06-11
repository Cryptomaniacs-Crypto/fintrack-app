# frozen_string_literal: true

require_relative 'app'
require_relative '../services/fintrack_api'
require_relative '../models/current_session'

module FinanceTracker
  class App < Roda
    route('friends') do |routing|
      require_login!(routing)
      current_sess      = FinanceTracker::CurrentSession.new(session)
      auth_token        = current_sess.auth_token
      account_api_token = current_sess.account_api_token
      api               = FinanceTracker::Services::FintrackApi.new

      routing.is do
        # GET /friends — list saved friends + add form
        routing.get do
          result  = api.list_friends(auth_token: auth_token, account_api_token: account_api_token)
          friends = result['data'] || []
          view 'friends/index', locals: { friends: friends }
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash.now[:error] = "Could not load friends: #{e.message}"
          view 'friends/index', locals: { friends: [] }
        end

        # POST /friends — add a friend by username
        routing.post do
          username = routing.params['username'].to_s.strip
          if username.empty?
            flash[:error] = 'Please enter a username.'
            routing.redirect '/friends'
          end

          api.add_friend(username, auth_token: auth_token, account_api_token: account_api_token)
          flash[:notice] = "Added @#{username} to your friends."
          routing.redirect '/friends'
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash[:error] = friend_error_message(e, username)
          routing.redirect '/friends'
        end
      end

      # DELETE /friends/:username — remove a friend
      routing.on String do |friend_username|
        routing.delete do
          api.remove_friend(friend_username, auth_token: auth_token, account_api_token: account_api_token)
          flash[:notice] = "Removed @#{friend_username} from your friends."
          routing.redirect '/friends'
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash[:error] = e.message
          routing.redirect '/friends'
        end
      end
    end

    private

    # Friendlier copy for the common add-friend failures.
    def friend_error_message(api_error, username)
      case api_error.status
      when 404 then "No user named @#{username} was found."
      when 409 then "@#{username} is already in your friends."
      when 422 then "You can't add yourself as a friend."
      else api_error.message
      end
    end
  end
end
