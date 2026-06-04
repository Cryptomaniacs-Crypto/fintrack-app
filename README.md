# fintrack-app

Server-rendered web client (Roda + Slim) that follows the FinanceTracker app structure.

## Pages

- `/` home
- `/auth/login` login
- `/auth/register` register
- `/account/:username` account overview (requires login)
- `/payment-methods` payment method list (requires login)
- `/payment-methods/new` create payment method form (requires login)
- `DELETE /account/:username` logout by clearing the session

Admin-only system role management routes also exist:

- `PUT /account/:username/system_roles/:role_name`
- `DELETE /account/:username/system_roles/:role_name`

This frontend is a session-based client for the API.

## Run

From WSL in this repo:

1. Install gems:

	`bundle install`

2. Generate a session encryption key:

	`bundle exec rake generate:msg_key`

3. Start the web app:

	`MSG_KEY=<base64 key> bundle exec rackup -p 9292`

4. Visit `http://localhost:9292`.

### Security/session environment variables

- `APP_URL` (Base URL for building registration verification links)
- `SECURE_SCHEME` (`HTTP` for development/test, `HTTPS` for production)  
  When set to `HTTPS`, the app redirects HTTP requests to HTTPS and sets HSTS.
- `MSG_KEY` (Base64 key)  
  Used by secure session encryption (`rake generate:msg_key`).
- `SESSION_SECRET` (recommended)  
  Session secret used by the Roda sessions plugin (generate via `bundle exec rake generate:session_secret`).
- `REDISCLOUD_URL` or `REDIS_URL` (required in production)  
  Production uses Redis-backed sessions; development/test use pooled in-memory sessions.
  Both standard Heroku Redis and RedisCloud add-ons are supported.

### Session storage strategy

- Development/Test: `Rack::Session::Pool`
- Production: `Rack::Session::Redis`

For `rediss://` URLs, the app uses TLS and disables certificate verification
to match managed Heroku Redis deployment behavior.

### Heroku Redis provisioning

1. Provision Redis add-on on the app.
2. Ensure one of these config vars exists:
   - `REDISCLOUD_URL` (RedisCloud)
   - `REDIS_URL` (Heroku Redis)
3. Set `SECURE_SCHEME=HTTPS`.
4. Set `MSG_KEY` using `bundle exec rake generate:msg_key`.

### Redis session maintenance

To wipe all Redis sessions (e.g., forced logout after key rotation):

`bundle exec rake session:wipe`

## API integration

The account overview attempts to load transactions from the FinTrack API:

- `FINTRACK_API_URL` (default: `http://localhost:3000`)
- `FINTRACK_API_URL` (default: `http://localhost:9292`)

Login attempts to authenticate via the API endpoint:

- `POST /api/v1/auth/authentication`

If the API is not running (or returns an error), the UI will show an empty list.

## Google SSO (OAuth) setup

This app implements an authorization-code based Google SSO flow. The web app builds a Google
authorization URL and verifies a per-session CSRF `state` value when Google redirects back to
`/auth/sso_callback`.

Required environment variables (set in your local shell or CI):

- `GOOGLE_CLIENT_ID` — OAuth client ID from Google Cloud.
- `GOOGLE_REDIRECT_URI` — The OAuth redirect URI (should point to `/auth/sso_callback`, e.g. `http://localhost:9292/auth/sso_callback`).
- `GOOGLE_OAUTH_URL` — Google's OAuth authorize endpoint (default: `https://accounts.google.com/o/oauth2/v2/auth`).
- `GOOGLE_SCOPE` — OAuth scopes to request (e.g. `openid email profile`).

How it works:

- When rendering `/auth/login`, the app generates (once per session) a random `sso_state` value
  and builds the Google authorize URL with `client_id`, `redirect_uri`, `scope`, `response_type=code`,
  and the `state` parameter.
- After the user authenticates with Google, Google redirects back to `/auth/sso_callback?code=...&state=...`.
- The app verifies the returned `state` matches the session `sso_state`, then POSTs the `code` to
  the backend API endpoint `/api/v1/auth/sso` via `AuthorizeGoogleAccount` service. The API performs
  the Google token exchange and returns `auth_token`, `account` and optionally `account_api_token`.
- The web app persists the returned `auth_token`, `account`, and `account_api_token` into the secure session.

Testing locally (no Google setup required):

- The tests use WebMock to stub `/api/v1/auth/sso` responses. You can run the SSO callback spec directly:

```bash
export MSG_KEY=$(bundle exec rake generate:msg_key 2>/dev/null | sed -n 's/^MSG_KEY: //p')
export SESSION_SECRET=$(bundle exec rake generate:session_secret 2>/dev/null | sed -n 's/^New SESSION_SECRET (base64): //p')
bundle exec rake spec SPEC=spec/integration/auth_sso_callback_spec.rb
```

If you want to test against real Google OAuth, register an OAuth client at https://console.cloud.google.com/apis/credentials,
set `GOOGLE_CLIENT_ID` and `GOOGLE_REDIRECT_URI` to match the OAuth credentials, and ensure `GOOGLE_OAUTH_URL` and
`GOOGLE_SCOPE` are configured as needed.