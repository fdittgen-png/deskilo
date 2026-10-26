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
}

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
  },
};

/** The environment variable holding [part] of [targetId]'s OAuth client. */
export function clientEnvName(
  targetId: string,
  part: "CLIENT_ID" | "CLIENT_SECRET",
): string {
  return `ACCOUNTING_${targetId.toUpperCase()}_${part}`;
}
