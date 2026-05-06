# fintrack-app

Server-rendered web client (Roda + Slim) that follows the FinanceTracker app structure.

## Pages

- `/` home
- `/auth/login` login
- `/auth/register` register
- `/account/:username` account overview (requires login)
- `DELETE /account/:username` logout by clearing the session

This frontend is a session-based client for the API. It does not expose admin/system-role management routes.

## Run

From WSL in this repo:

1. Install gems:

	`bundle install`

2. Start the web app:

	`SESSION_SECRET=change-me bundle exec rackup -p 9292`

3. Visit `http://localhost:9292`.

## API integration

The account overview attempts to load transactions from the FinTrack API:

- `FINTRACK_API_URL` (default: `http://localhost:3000`)

Login attempts to authenticate via the API endpoint:

- `FINTRACK_API_AUTH_PATH` (default: `/api/v1/auth/login`)

If the API is not running (or returns an error), the UI will show an empty list.