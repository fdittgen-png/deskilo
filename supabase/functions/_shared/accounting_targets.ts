// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The accounting targets an issuer signs in to (OAuth 2.0 authorisation
// code): where the authorisation page and the token endpoint are, which
// scopes a delivery needs, and the query parameter a target uses to name
// the remote company in its redirect, if any. The app's descriptor
// (`accounting_target.dart`) says WHICH targets take a sign-in; this table
// says HOW, and the two agree by target id
// (test/features/money/accounting_targets_test.dart).
//
// The app's OAuth client of each target is the installation's own: its id
// and secret are the function's environment
// (`ACCOUNTING_<TARGET>_CLIENT_ID`, `ACCOUNTING_<TARGET>_CLIENT_SECRET`),
// never a row a client could read. An installation that registered no app
// with a target answers `oauth_not_configured`, and the person connects
// with an API token instead where the target offers one.

export interface OAuthTarget {
  authorizeUrl: string;
  tokenUrl: string;
  scopes: string[];
  /** The redirect's query parameter naming the remote company, if any. */
  tenantParam?: string;
  /** How long a sign-in may take from the authorisation page to the
   * redirect; an older state is refused before any exchange, so a redirect
   * URL found later in a history or a referrer cannot connect a company. */
  stateLifetimeMs: number;
}

// spec: developer.intuit.com — "OAuth 2.0" (Intuit apps): the authorisation
// page on appcenter.intuit.com, the token endpoint on
// oauth.platform.intuit.com, the accounting scope, and the redirect naming
// the company in `realmId`. One Intuit application serves the three
// countries. Not yet verified against a registered Intuit application.
const quickbooksOnline: OAuthTarget = {
  authorizeUrl: "https://appcenter.intuit.com/connect/oauth2",
  tokenUrl: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer",
  scopes: ["com.intuit.quickbooks.accounting"],
  tenantParam: "realmId",
  // A person signing in, not a batch: ten minutes.
  stateLifetimeMs: 10 * 60 * 1000,
};

// spec: developer.xero.com — "OAuth 2.0 / Auth flow" (web apps): the
// authorisation page on login.xero.com, the token endpoint on
// identity.xero.com, offline_access for a rotating refresh token. The
// redirect names no organisation: the sign-in's organisation is read from
// GET /connections (accounting_xero.ts `signedInTenant`). One Xero
// application serves the four regions. The scopes are the broad ones the
// issue names; an application registered after Xero's granular scopes
// (accounting.invoices, accounting.payments, ...) needs those instead. Not
// yet verified against a registered Xero application. No attachment scope:
// no attachment is sent yet.
const xero: OAuthTarget = {
  authorizeUrl: "https://login.xero.com/identity/connect/authorize",
  tokenUrl: "https://identity.xero.com/connect/token",
  scopes: ["offline_access", "accounting.transactions", "accounting.contacts", "accounting.settings.read"],
  // A person signing in, not a batch: ten minutes.
  stateLifetimeMs: 10 * 60 * 1000,
};

export const oauthTargets: Record<string, OAuthTarget> = {
  // spec: developers.pennylane.com — "OAuth 2.0" (partner applications):
  // authorisation and token endpoints on app.pennylane.com, scopes per
  // resource. Not yet verified against a registered partner application.
  pennylane_api: {
    authorizeUrl: "https://app.pennylane.com/oauth/authorize",
    tokenUrl: "https://app.pennylane.com/oauth/token",
    scopes: [
      "customer_invoices:all",
      "customers:all",
      "file_attachments:all",
      "ledger_entries:all",
    ],
    // A person signing in, not a batch: ten minutes.
    stateLifetimeMs: 10 * 60 * 1000,
  },
  quickbooks_online_us: { ...quickbooksOnline },
  quickbooks_online_ca: { ...quickbooksOnline },
  quickbooks_online_gb: { ...quickbooksOnline },
  xero_gb: { ...xero },
  xero_ca: { ...xero },
  xero_us: { ...xero },
  xero_eu: { ...xero },
};

/** The environment variable holding [part] of [targetId]'s OAuth client. */
export function clientEnvName(
  targetId: string,
  part: "CLIENT_ID" | "CLIENT_SECRET",
): string {
  return `ACCOUNTING_${targetId.toUpperCase()}_${part}`;
}
