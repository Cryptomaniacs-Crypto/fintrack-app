# FinTrack Web App — Project Progress

## Snapshot (May 26, 2026)
Server-rendered web client for the FinTrack API using Roda + Slim.

## Repo Facts
- **Web app**: Roda app mounted via [config.ru](config.ru)
- **Default dev port**: 9292 (see `rake run:dev` in `Rakefile`)
- **API base URL**: `FINTRACK_API_URL` (defaults to `http://localhost:9292` in service clients)

## Current Architecture

### Controllers (app/controllers/)
- `app.rb`
  - Loads Slim views + assets
  - Sets `@current_account` from encrypted session via `SecureSession.get(session, 'current_account')`
  - Helpers:
    - `require_login!(routing)`
    - `system_admin?(current_account=nil)`
- `auth.rb`
  - `GET /auth/login` (form)
  - `POST /auth/login` → `Services::AuthenticateAccount` and stores both account + auth token via `CurrentSession`
  - `GET /auth/register` (start registration)
  - `GET /auth/register/:token` (confirm)
  - `POST /auth/register` (initiate verification email)
  - `GET /auth/logout` (clears session)
- `account.rb`
  - `GET /account` redirects to current user’s account page
  - `GET /account/:username` (requires login; admins can view other users)
  - `DELETE /account/:username` (clears session)
  - Admin-only system role management:
    - `PUT /account/:username/system_roles/:role_name`
    - `DELETE /account/:username/system_roles/:role_name`
- `payment_methods.rb`
  - `GET /payment-methods` (list)
  - `GET /payment-methods/new` (form)
  - `POST /payment-methods` (create)

### Models + Session (app/models/, app/lib/)
- `SecureMessage` (NaCl SimpleBox)
  - Requires `MSG_KEY` (base64) to encrypt/decrypt payloads
- `SecureSession`
  - Stores encrypted JSON blobs inside Rack session keys (`current_account`, `auth_token`)
  - Includes a Redis-session wipe helper used by `rake session:wipe`
- `CurrentSession`
  - High-level accessor around `SecureSession` for `current_account` and `auth_token`

### Services (app/services/)
- `ApiClient`
  - HTTP wrapper using the `http` gem
  - Raises `ApiClient::ApiError` on non-2xx and exposes `status` + `body`
- `AuthenticateAccount`
  - Calls `POST /api/v1/auth/authentication`
  - Parses `included['system_roles']` into role name strings
  - Returns `{ account:, auth_token: }` and (when given `current_session:`) persists both into session
- `VerifyRegistration` → `POST /api/v1/auth/register`
- `CreateAccount` → `POST /api/v1/accounts`
- Payment methods:
  - `ListPaymentMethods` → `GET /api/v1/wallets`
  - `CreatePaymentMethod` → `POST /api/v1/wallets`
- Accounts/roles (admin flows): `GetAccount`, `AssignSystemRole`, `RevokeSystemRole`
- Transactions (account page for self): `FintrackApi#list_transactions` → `GET /api/v1/transactions`

## Environment / Security
- `MSG_KEY` (required): encryption key for `SecureMessage` (`bundle exec rake generate:msg_key`)
- `FINTRACK_API_URL`: base URL of fintrack-api (defaults to `http://localhost:9292`)
- `APP_URL`: used to generate verification links in registration flow
- Production:
  - `SECURE_SCHEME=HTTPS` (enables HTTPS redirect + HSTS)
  - `REDISCLOUD_URL` or `REDIS_URL` (Redis-backed sessions)
  - For `rediss://`, Redis TLS is used with cert verification disabled to match managed Heroku Redis behavior

## Completed ✅ (in this repo)
- Registration start + verification-link confirmation flow wired to API
- Account creation flow (`/api/v1/accounts`) wired
- Login/logout routes implemented and session persistence handled via `CurrentSession`
- Account page with viewer/target authorization checks
- Payment method list/create flows implemented
- Service integration tests exist for auth, registration verification, and account creation

## Known Gaps / Risks
- API contract assumptions (auth path and response shape) must match the fintrack-api you’re running/deploying:
  - Current auth call is `POST /api/v1/auth/authentication`
  - If your API uses a different login route, update `AuthenticateAccount` (and corresponding spec stubs)
- Docs previously referenced multiple ports/paths; this file now reflects the code in-repo.

## Next Steps
1. Verify fintrack-api supports `POST /api/v1/auth/authentication` in the target environment
2. Exercise end-to-end flows against a running API:
   - Register → confirm → create account → login → list/create payment methods
3. Run tests: `bundle exec rake spec`

## Sprint P3 — Account API token integration (Jun 4, 2026)
- **Goal:** Align with upstream branch `5-account-api-token` (ISS-Security/tyto2026-app) to support account-level API tokens returned by the API and used by service clients.
- **Status:** In progress (assigned: p3)
- **Scope:**
  - Update `ApiClient` and service wrappers to accept and forward the account API token header alongside auth token
  - Persist `account_api_token` in `SecureSession`/`CurrentSession` when returned by authentication/creation endpoints
  - Update `Services::AuthenticateAccount`, `CreateAccount`, and `ListPaymentMethods` to handle the new token
  - Add/adjust integration tests to reflect the API response shape and header usage
- **Acceptance:** End-to-end flows (register → confirm → login → list payment methods) pass locally against an API that returns `account_api_token` and clients send it on subsequent requests.
