// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3905 -- the operator's switch for an installation that rehearses payments
// (a rehearsal installation, CI): with DESKILO_ALLOW_TEST_PAYMENTS=true in the
// functions' environment, `create-payment-order` opens an order under test
// credentials and the three webhooks process test-mode events. Without it, a
// production workspace takes real money only. It is read from the environment
// on every request, never from a workspace or a caller.

/** The environment variable that switches test payments on. */
export const ALLOW_TEST_PAYMENTS = "DESKILO_ALLOW_TEST_PAYMENTS";

/** Whether this installation takes test payments. */
export const allowsTestPayments = (
  env: (name: string) => string | undefined = (name) => Deno.env.get(name),
): boolean => env(ALLOW_TEST_PAYMENTS) === "true";
