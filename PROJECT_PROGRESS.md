# FinTrack Web App - Project Progress

## Project Overview
Building an authenticated web client for fintrack-api using Roda framework + Slim templates.
- **Location**: `\\wsl.localhost\Ubuntu\home\charleneshawn\ServiceSecurity\fintrack-app`
- **API**: fintrack-api running on `http://localhost:9292` (port 9292, NOT 3000)
- **Web App Port**: 9090
- **Framework**: Roda 3.0 + Slim templating
- **Session**: Cookie-based with Roda sessions plugin

## Architecture

### Controllers (app/controllers/)
- **app.rb**: Base Roda class, session setup, global helpers
  - `system_admin?` helper - checks if user has 'admin' role
  - `require_login!` helper - redirects to login if not authenticated
  - Session access: `session['current_account']` (STRING key, not symbol!)
  
- **auth.rb**: Login, logout, register routes
  - POST /auth/login → calls AuthenticateAccount service
  - Session stores account hash with: id, username, email, avatar, system_roles (array of role names)
  
- **account.rb**: Account overview, admin role management
  - GET /account/:username → displays account details
  - Admin routes for granting/revoking system roles (PUT/DELETE)

### Services (app/services/)
- **api_client.rb**: HTTP wrapper using http gem
  - Raises ApiClient::ApiError for non-2xx responses
  - Stores status code + body in error
  
- **authenticate_account.rb**: Login service
  - Calls POST /api/v1/auth/authentication
  - **CRITICAL FIX**: Response.included is a Hash with 'system_roles' key, NOT an array!
  - Returns account hash with system_roles as array of role name strings
  
- **get_account.rb**: Admin account lookup
- **assign_system_role.rb**, **revoke_system_role.rb**: Role management

### Views (app/presentation/views/)
- **layout.slim**: Base template with Bootstrap 5 Cerulean theme
- **login.slim**: Login form
- **account.slim**: Account page with role badges
- CSS: `app/presentation/assets/css/style.css` (moved from old location)

## Completed ✅
1. Roda session setup with 64+ char secret validation
2. Login flow wired to API
3. Session persistence with system_roles
4. Account page display
5. Admin role checking
6. Bootstrap UI styling
7. CSS file in correct location
8. Authentication parsing fixed for API response shape
9. **Session key fix**: Changed from `:current_account` (symbol) to `'current_account'` (string)

## Current Issues 🔴
### Issue: Login redirect flow
- **Reference pattern**: Successful login redirects to `/`, then the home page uses the session-backed account state
- **Local fix applied**: Successful login now follows the same flow instead of redirecting straight to `/account/username`
- **Follow-up**: Keep an eye on direct account-page access, especially for admin views and API calls that still depend on the backend URL

## Key Fixes Applied

### 1. Session Key Mismatch (MAIN FIX)
```ruby
# WRONG (was using symbol):
@current_account = session[:current_account]
session[:current_account] = account

# CORRECT (use string):
@current_account = session['current_account']
session['current_account'] = account
```
Applied to:
- app/controllers/app.rb (line ~25)
- app/controllers/auth.rb (login, logout routes)
- app/controllers/account.rb (logout route)

### 2. API Response Parsing
```ruby
# API returns: { "data" => { "attributes" => {...} }, "included" => { "system_roles" => [...] } }
account = response.fetch('data', {}).fetch('attributes', {})
included = response['included'] || {}
system_roles_array = included['system_roles'] || []
account.merge('system_roles' => system_roles_array.map { |role| role['name'] })
```

### 3. API Base URL
- Changed from port 3000 to 9292 in api_client.rb:
  - `ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292')`

### 4. CSS File Location
- Moved from: `app/presentation/assets/style.css`
- Moved to: `app/presentation/assets/css/style.css`

## Environment
- SESSION_SECRET: Must be 64+ chars (validated at startup)
- FINTRACK_API_URL: Defaults to http://localhost:9292
- Ruby 4.0.2
- Roda 3.0 with plugins: render, assets, multi_route, flash, sessions

## Testing Checklist
- [ ] Login with correct credentials → redirects to account page without needing refresh
- [ ] Wrong password → shows "Username and password did not match" error
- [ ] Admin user can view other accounts
- [ ] Admin can grant/revoke system roles
- [ ] Logout works correctly
- [ ] Flash messages display correctly
- [ ] System roles display as badges on account page

## Next Steps
1. Debug why redirect after login sometimes fails (investigate transactions list)
2. Potentially render account page directly instead of redirecting
3. Test admin role management flows
4. Verify logout clears session properly
