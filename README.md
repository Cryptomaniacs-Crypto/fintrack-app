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

This frontend is a session-based client for the API. It does not expose admin/system-role management routes.

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

- `SECURE_SCHEME` (`HTTP` for development/test, `HTTPS` for production)  
  When set to `HTTPS`, the app redirects HTTP requests to HTTPS and sets HSTS.
- `MSG_KEY` (Base64 key)  
  Used by secure session encryption (`rake generate:msg_key`).
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

Login attempts to authenticate via the API endpoint:

- `FINTRACK_API_AUTH_PATH` (default: `/api/v1/auth/login`)

If the API is not running (or returns an error), the UI will show an empty list.