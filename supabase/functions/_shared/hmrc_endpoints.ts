// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — which HMRC the installation talks to. The two hosts of each HMRC
// environment are EXACT approved origins, fixed here; the installation only
// CHOOSES the environment (`HMRC_ENVIRONMENT=sandbox|production`, a setting of
// the function like its client id and secret). No client value, no wildcard
// and no suffix match ever builds a URL: the sign-in page, the token
// endpoint and every API call come from this table or nowhere.

export interface HmrcEndpoints {
  /** The API and token host. */
  api: string;
  /** The page the person signs in on: a different host. */
  signIn: string;
}

export const HMRC_ENVIRONMENTS: Record<string, HmrcEndpoints> = {
  // spec: developer.service.hmrc.gov.uk — "Making Tax Digital" test and
  // live environments.
  sandbox: {
    api: "https://test-api.service.hmrc.gov.uk",
    signIn: "https://test-www.tax.service.gov.uk",
  },
  production: {
    api: "https://api.service.hmrc.gov.uk",
    signIn: "https://www.tax.service.gov.uk",
  },
};

/** The endpoints the installation chose, or null when it chose none or an
 * environment this module does not know (the function then answers
 * `hmrc_not_configured`). */
export function hmrcEndpoints(
  env: (name: string) => string | undefined,
): HmrcEndpoints | null {
  const chosen = (env("HMRC_ENVIRONMENT") ?? "").trim().toLowerCase();
  return Object.hasOwn(HMRC_ENVIRONMENTS, chosen)
    ? HMRC_ENVIRONMENTS[chosen]
    : null;
}

/** Whether [url] sits on one of the approved origins, exactly. */
export function isApprovedHmrcUrl(url: string): boolean {
  let origin: string;
  try {
    const u = new URL(url);
    if (u.protocol !== "https:" || u.username || u.password) return false;
    origin = u.origin;
  } catch {
    return false;
  }
  return Object.values(HMRC_ENVIRONMENTS).some((e) =>
    e.api === origin || e.signIn === origin
  );
}
