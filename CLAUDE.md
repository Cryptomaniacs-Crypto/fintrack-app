# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
bundle install

# Run development server (port 9292)
bundle exec rake run:dev
# Or directly: puma -p 9292

# Run all tests
bundle exec rake spec

# Run a single spec file
bundle exec rake spec SPEC=spec/integration/transactions_feature_spec.rb

# Watch tests on code changes
bundle exec rake respec

# Lint
bundle exec rake style

# Generate required keys (run once per environment)
bundle exec rake generate:msg_key       # → set as MSG_KEY env var
bundle exec rake generate:session_secret  # → set as SESSION_SECRET env var

# Open console
bundle exec rake console

# Wipe Redis sessions (after key rotation)
bundle exec rake session:wipe
```

Required env vars for local dev: `MSG_KEY`, `FINTRACK_API_URL` (e.g. `http://localhost:3000`).

## Architecture

This is a **Roda + Slim frontend** that talks to a separate FinTrack JSON API. It holds no database of its own — all data lives in the API. The app is purely session-based.

### Request flow

```
Browser → Roda router (app/controllers/) → Service (app/services/) → API (HTTP)
                                         → Form validator (app/forms/)
                                         → Model/parser (app/models/)
                                         → View (app/presentation/views/)
```

### Key architectural points

**Controllers are Roda route files**, each `require`d by `require_app` at boot. They all reopen `FinanceTracker::App < Roda` and register a named route via `route('segment')`. The root dispatcher is `app/controllers/app.rb` which calls `routing.multi_route` to delegate to these files.

**Models are API response parsers only** — no ORM, no DB. They unwrap the JSON envelope (`data.attributes`) returned by the API. `PaymentMethod` and `Wallet` are two wrappers for the same API resource.

**Services call the API** via `ApiClient` (wraps the `http` gem). Auth is passed as `Authorization: Bearer <token>` on each call. The token is stored encrypted in the session via `SecureMessage` (NaCl SecretBox).

**Session storage**: `Rack::Session::Pool` in dev/test, `Rack::Session::Redis` in production (uses `REDISCLOUD_URL` or `REDIS_URL`). The session holds `current_account` (user info) and `auth_token` (API bearer token), both encrypted with `MSG_KEY`.

**Forms use dry-validation contracts** in `app/forms/`. `CreateTransaction` and `UpdateTransaction` are both defined in the same file (`create_transaction.rb`).

**Views are Slim templates** rendered by Roda's `:render` plugin. Layout is `app/presentation/views/layout.slim`. Bootstrap 5 (Bootswatch Cerulean theme) + custom CSS at `app/presentation/assets/css/style.css`.

### Route map (current)

| Path | Controller file |
|------|----------------|
| `/auth/*` | `auth.rb` |
| `/account/:username` | `account.rb` |
| `/admin/*` | `admin.rb` |
| `/payment-methods/*` | `payment_methods.rb` |
| `/transactions/*` | `transactions.rb` |
| `/bill-splits/*` | `bill_splits.rb` |

### Transaction type encoding

Transfers post once to the API's **atomic `POST /api/v1/transfers`** endpoint
(`Services::CreateTransfer` → `ApiClient`). The API creates both legs — an
`expense` on the source wallet (title prefixed `"Transfer → "`) and an `income`
on the destination wallet (title prefixed `"Transfer ← "`) — inside a single DB
transaction, so a half-completed transfer can never be observed. The two-leg
title prefix is still how `Transaction#transfer?`, list filtering, and CSV export
recognise a transfer. (Previously the app made two separate `POST /transactions`
calls, which were not atomic.)

### Categories

Categories come from `GET /api/v1/categories`. The `Category` model exposes `can_edit?` / `can_delete?` policies from the API response, used to gate UI affordances for user-created categories.

### Deployment

Heroku app: `sud-fintrack-app` (remote: `heroku`). Deploy with:
```bash
git push heroku <branch>:main
```
