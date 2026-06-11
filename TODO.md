# TODO — Sprint P3 (account-api-token)

Context: follow the instructor's branch `5-account-api-token` from ISS-Security/tyto2026-app and align our repo accordingly.

Priority tasks (owner: p3)

1. Compare upstream changes
   - Pull diffs from `ISS-Security/tyto2026-app` branch `5-account-api-token` and identify service and client changes.
2. Update session handling
   - Persist `account_api_token` in `SecureSession` / `CurrentSession` when returned by the API.
3. Update service clients
   - Modify `ApiClient` to accept and forward `Account-Api-Token` (or configured header) on requests when present.
4. Update services
   - Update `Services::AuthenticateAccount`, `CreateAccount`, and `ListPaymentMethods` to read and return the account token.
5. Update controllers/views
   - Ensure controllers populate session with the new token so subsequent service calls include it.
6. Tests
   - Update/extend integration tests in `spec/integration/` to assert header presence and token persistence.
7. Docs
   - Update `PROJECT_PROGRESS.md` (done) and add a short note in `README.md` about new env/config if needed.

Quick next steps for you (p3):
- Pull the instructor branch and open diffs for `app/services` and `lib`.
- Implement steps 2–4 locally, run `bundle exec rake spec`, and iterate on failing tests.

If you want, I can fetch the upstream branch diffs now and generate a focused patch list. Proceed? 
