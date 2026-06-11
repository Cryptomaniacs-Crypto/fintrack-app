# frozen_string_literal: true

require 'base64'
require_relative 'app'
require_relative '../services/fintrack_api'
require_relative '../services/get_account'
require_relative '../services/create_account'
require_relative '../services/assign_system_role'
require_relative '../services/revoke_system_role'
require_relative '../services/update_username'
require_relative '../services/banner_image'
require_relative '../forms/change_username'
require_relative '../lib/registration_token'
require_relative '../lib/secure_session'

module FinanceTracker
  # Account pages and account-level actions for the web app.
  class App < Roda
    route('account') do |routing|
      routing.is do
        require_login!(routing)

        routing.get do
          return routing.redirect '/auth/login' unless @current_account && @current_account['username']

          routing.redirect "/account/#{@current_account['username']}"
        end
      end

      # Home-banner cover photo for the logged-in user. Literal 'banner' segment
      # must come before the String matcher below so it isn't read as a username.
      routing.on 'banner' do
        require_login!(routing)
        uname = @current_account['username']
        sess = FinanceTracker::CurrentSession.new(session)
        auth_token = sess.auth_token
        account_api_token = sess.account_api_token
        banner = FinanceTracker::Services::BannerImage.new(App.config)

        # GET /account/banner/image -- stream the user's cover (or a transparent pixel)
        routing.get 'image' do
          data = banner.fetch(username: uname, auth_token: auth_token, account_api_token: account_api_token)
          response['Content-Type'] = data['content_type'] || 'image/png'
          response['Cache-Control'] = 'no-cache'
          Base64.strict_decode64(data['image_base64'].to_s)
        rescue FinanceTracker::Services::ApiClient::ApiError
          response['Content-Type'] = 'image/png'
          Base64.strict_decode64(TRANSPARENT_PNG)
        end

        # POST /account/banner -- upload/replace the cover
        routing.is do
          routing.post do
            image_base64, content_type = read_banner_upload(routing.params['banner'])
            if image_base64.nil?
              flash[:error] = 'Please choose a PNG or JPEG image to upload'
              routing.redirect '/'
            end
            banner.upload(username: uname, image_base64: image_base64, content_type: content_type,
                          auth_token: auth_token, account_api_token: account_api_token)
            flash[:notice] = 'Cover photo updated'
            routing.redirect '/'
          rescue FinanceTracker::Services::ApiClient::ApiError => e
            flash[:error] = "Could not update cover photo: #{e.message}"
            routing.redirect '/'
          end
        end

        # POST /account/banner/remove -- clear the cover
        routing.post 'remove' do
          banner.remove(username: uname, auth_token: auth_token, account_api_token: account_api_token)
          flash[:notice] = 'Cover photo removed'
          routing.redirect '/'
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash[:error] = "Could not remove cover photo: #{e.message}"
          routing.redirect '/'
        end
      end

      routing.on String do |username_or_token|
        # POST /account/[username]/username -- owner changes their handle.
        # Must come BEFORE the bare `routing.post` below, which would otherwise
        # match any POST under /account/[x] and swallow this one.
        routing.on 'username' do
          routing.post do
            require_login!(routing)
            sess = FinanceTracker::CurrentSession.new(session)

            unless username_or_token == @current_account['username']
              flash[:error] = 'You can only change your own username'
              routing.redirect "/account/#{@current_account['username']}"
            end

            new_username = routing.params['username'].to_s.strip
            validation = FinanceTracker::Form::ChangeUsername.call(username: new_username)
            if validation.failure?
              flash[:error] = "Invalid username: #{validation.errors[:username]&.first}"
              routing.redirect "/account/#{username_or_token}"
            end

            FinanceTracker::Services::UpdateUsername.new(App.config).call(
              current_username: username_or_token, new_username: new_username,
              auth_token: sess.auth_token, account_api_token: sess.account_api_token
            )

            # Reflect the new handle in the session without touching the auth token.
            info = FinanceTracker::SecureSession.get(session, 'current_account') || {}
            info['username'] = new_username
            FinanceTracker::SecureSession.set(session, 'current_account', info)

            flash[:notice] = "Username changed to #{new_username}"
            routing.redirect "/account/#{new_username}"
          rescue FinanceTracker::Services::UpdateUsername::UsernameTaken
            flash[:error] = "Username '#{routing.params['username']}' is already taken"
            routing.redirect "/account/#{username_or_token}"
          rescue FinanceTracker::Services::UpdateUsername::InvalidUsername => e
            flash[:error] = "Invalid username: #{e.message}"
            routing.redirect "/account/#{username_or_token}"
          rescue StandardError => e
            App.logger.error "USERNAME CHANGE ERROR: #{e.inspect}"
            flash[:error] = 'Could not change username -- please try again'
            routing.redirect "/account/#{username_or_token}"
          end
        end

        routing.post do
          token = RegistrationToken.load(username_or_token)
          password = routing.params['password'].to_s
          password_confirm = routing.params['password_confirm'].to_s

          if password.empty? || password != password_confirm
            flash[:error] = 'Passwords did not match'
            routing.redirect "/auth/register/#{username_or_token}"
          end

          current_sess = FinanceTracker::CurrentSession.new(session)
          FinanceTracker::Services::CreateAccount.new(App.config, current_session: current_sess).call(
            email: token.email,
            username: token.username,
            password: password
          )
          flash[:notice] = 'Account created -- please log in'
          routing.redirect '/auth/login'
        rescue RegistrationToken::InvalidTokenError
          flash[:error] = 'Verification link is invalid or expired'
          routing.redirect '/auth/register'
        rescue FinanceTracker::Services::CreateAccount::InvalidAccount => e
          flash[:error] = e.message.empty? ? 'Could not create account' : e.message
          routing.redirect '/auth/register'
        rescue StandardError => e
          App.logger.error "ERROR CREATING ACCOUNT: #{e.inspect}"
          flash[:error] = 'Could not create account'
          routing.redirect '/auth/register'
        end

        require_login!(routing)
        current_sess = FinanceTracker::CurrentSession.new(session)
        auth_token = current_sess.auth_token
        account_api_token = current_sess.account_api_token
        username = username_or_token

        unless username == @current_account['username'] || system_admin?(@current_account)
          flash[:error] = 'You can only view your own account page'
          return routing.redirect '/auth/login' unless @current_account && @current_account['username']

          routing.redirect "/account/#{@current_account['username']}"
        end

        routing.on 'roles' do
          routing.on String do |role_name|
            unless system_admin?(@current_account)
              flash[:error] = 'Only admins can manage system roles'
              routing.redirect "/account/#{@current_account['username']}"
            end

            routing.put do
              FinanceTracker::Services::AssignSystemRole.new(App.config).call(
                auth_token: auth_token,
                target_username: username,
                role_name: role_name,
                account_api_token: account_api_token
              )
              flash[:notice] = "Granted #{role_name} to #{username}"
              routing.redirect "/account/#{username}"
            rescue StandardError => e
              flash[:error] = "Could not grant role: #{e.message}"
              routing.redirect "/account/#{username}"
            end

            routing.delete do
              FinanceTracker::Services::RevokeSystemRole.new(App.config).call(
                auth_token: auth_token,
                target_username: username,
                role_name: role_name,
                account_api_token: account_api_token
              )
              flash[:notice] = "Revoked #{role_name} from #{username}"
              routing.redirect "/account/#{username}"
            rescue StandardError => e
              flash[:error] = "Could not revoke role: #{e.message}"
              routing.redirect "/account/#{username}"
            end
          end
        end

        routing.is do
          routing.get do
            target_account = load_account(username, account_api_token: account_api_token)
            transactions =
              if username == @current_account['username']
                FinanceTracker::Services::FintrackApi.new.list_transactions(auth_token: auth_token, account_api_token: account_api_token)
              else
                []
              end

            view :account, locals: { account: target_account, viewer: @current_account, transactions: transactions, account_api_token: account_api_token }
          rescue FinanceTracker::Services::ApiClient::ApiError => e
            flash[:error] = "Could not load account: #{e.message}"
            return routing.redirect '/auth/login' unless @current_account && @current_account['username']

            routing.redirect "/account/#{@current_account['username']}"
          end

          routing.delete do
            SecureSession.delete(session, 'current_account')
            SecureSession.delete(session, 'auth_token')
            SecureSession.delete(session, 'account_api_token')
            flash[:notice] = 'Logged out'
            routing.redirect '/auth/login'
          end
        end
      end
    end

    private

    # 1x1 transparent PNG — shown when the user has no cover (banner falls back
    # to the default navy panel behind it).
    TRANSPARENT_PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='

    # Read a multipart image upload (Rack gives a Hash with :tempfile/:type) and
    # return [base64, content_type], or [nil, nil] when nothing was uploaded.
    def read_banner_upload(upload)
      return [nil, nil] unless upload.is_a?(Hash) && upload[:tempfile]

      bytes = upload[:tempfile].read
      return [nil, nil] if bytes.to_s.empty?

      [Base64.strict_encode64(bytes), upload[:type]]
    end

    def load_account(username, account_api_token: nil)
      return @current_account if username == @current_account['username']

      raise StandardError, 'Not authorized' unless system_admin?(@current_account)

      current_sess = FinanceTracker::CurrentSession.new(session)
      auth_token = current_sess.auth_token
      FinanceTracker::Services::GetAccount.new.call(username, auth_token: auth_token, account_api_token: account_api_token)
    end
  end
end
