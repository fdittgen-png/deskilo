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

import { HMRC_ENVIRONMENTS } from "./hmrc_endpoints.ts";
import { hmrcTarget } from "./hmrc_mtd.ts";

export interface OAuthTarget {
  authorizeUrl: string;
  tokenUrl: string;
  scopes: string[];
  /** The redirect's query parameter naming the remote company, if any. */
  tenantParam?: string;
  /** The target's token revocation endpoint (RFC 7009), when it documents
   * one. A target without one is revoked in DesKilo only, and the person
   * is told to remove the app in the target's own settings. */
  revokeUrl?: string;
  /** How that endpoint wants the token: a form (RFC 7009, the default) or
   * JSON (Intuit). */
  revokeBody?: "form" | "json";
  /** How the app authenticates at the token endpoint: HTTP Basic (RFC 6749
   * §2.3.1, the default) or client_id/client_secret in the server-to-server
   * form body, which HMRC documents (#2470). Never a browser URL. */
  clientAuth?: "basic" | "body";
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
  // spec: developer.intuit.com — "Revoke token": POST to
  // developer.api.intuit.com/v2/oauth2/tokens/revoke with the client as
  // basic auth and a JSON body {token}. Not yet verified against a
  // registered Intuit application.
  revokeUrl: "https://developer.api.intuit.com/v2/oauth2/tokens/revoke",
  revokeBody: "json",
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
  // spec: developer.xero.com — "Revoke refresh token": RFC 7009 on
  // identity.xero.com/connect/revocation. Not yet verified against a
  // registered Xero application.
  revokeUrl: "https://identity.xero.com/connect/revocation",
  scopes: ["offline_access", "accounting.transactions", "accounting.contacts", "accounting.settings.read"],
  // A person signing in, not a batch: ten minutes.
  stateLifetimeMs: 10 * 60 * 1000,
};

// #2373 — spec: developer.sage.com/accounting — "Authenticating with
// Sage Accounting": the central authorisation page on www.sageone.com
// (filter apiv3.1), the token endpoint on oauth.accounting.sage.com, the
// full_access scope (the API has no narrower write scope). The redirect
// names no business: the sign-in's business is read from GET /businesses
// (accounting_sage.ts `signedInTenant`). One Sage application serves the
// seven regions. Not yet verified against a registered Sage application.
const sageAccounting: OAuthTarget = {
  authorizeUrl: "https://www.sageone.com/oauth2/auth/central?filter=apiv3.1",
  tokenUrl: "https://oauth.accounting.sage.com/token",
  scopes: ["full_access"],
  // A person signing in, not a batch: ten minutes.
  stateLifetimeMs: 10 * 60 * 1000,
};

export const oauthTargets: Record<string, OAuthTarget> = {
  // #2377 — spec: docs.bexio.com — "Authentication" (OpenID Connect on
  // auth.bexio.com, realm bexio): the authorisation and token endpoints,
  // offline_access for a refresh token, a scope per resource. Not yet
  // verified against a registered bexio app.
  bexio_api: {
    authorizeUrl: "https://auth.bexio.com/realms/bexio/protocol/openid-connect/auth",
    tokenUrl: "https://auth.bexio.com/realms/bexio/protocol/openid-connect/token",
    // The realm is Keycloak, whose standard revocation endpoint (RFC 7009)
    // this is. Not yet verified against a registered bexio app.
    revokeUrl: "https://auth.bexio.com/realms/bexio/protocol/openid-connect/revoke",
    scopes: [
      "openid",
      "offline_access",
      "contact_show",
      "kb_invoice_edit",
      "kb_credit_voucher_edit",
    ],
    // A person signing in, not a batch: ten minutes.
    stateLifetimeMs: 10 * 60 * 1000,
  },
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
  // #2470 — HMRC: listed here so the table names every sign-in target of the
  // app, with the PRODUCTION hosts as its static value; the function resolves
  // HMRC through `targetOf` (connection.ts), which takes the installation's
  // chosen environment, so nothing reads this entry for a call.
  hmrc_mtd: { ...hmrcTarget(HMRC_ENVIRONMENTS.production.api, HMRC_ENVIRONMENTS.production.signIn) },
  xero_gb: { ...xero },
  xero_ca: { ...xero },
  xero_us: { ...xero },
  xero_eu: { ...xero },
  sage_business_cloud_gb: { ...sageAccounting },
  sage_business_cloud_ie: { ...sageAccounting },
  sage_business_cloud_ca: { ...sageAccounting },
  sage_business_cloud_us: { ...sageAccounting },
  sage_business_cloud_fr: { ...sageAccounting },
  sage_business_cloud_de: { ...sageAccounting },
  sage_business_cloud_es: { ...sageAccounting },
};

/** The environment variable holding [part] of [targetId]'s OAuth client. */
export function clientEnvName(
  targetId: string,
  part: "CLIENT_ID" | "CLIENT_SECRET",
): string {
  return `ACCOUNTING_${targetId.toUpperCase()}_${part}`;
}
