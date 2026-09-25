# payments.stripe — stripe test-mode run

A dated record for the `provider_sandbox` scope of `payments.stripe` (#1634, #1637):
the provider's TEST environment and a disposable backend, never a stub.

scope: provider_sandbox
capability: payments.stripe
sha: 232efc0a817596dfb69ed8b79e3064370d2fe10e
date: 2026-09-25
outcome: skipped
result: not_run
fingerprint: 38ddbebce0f4
provider: stripe (test mode)
api_version: n/a
runner: scripts/payment_sandbox_check.sh

Not run: missing STRIPE_TEST_SECRET_KEY STRIPE_TEST_WEBHOOK_SECRET SANDBOX_URL SANDBOX_ANON_KEY SANDBOX_SERVICE_ROLE_KEY SANDBOX_DB_URL psql. No request was made and nothing is claimed.
