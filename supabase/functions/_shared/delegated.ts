// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1614 — who is calling a user-facing Edge function. A token whose
// claims carry `client_id` was issued to a third-party OAuth client (an
// MCP assistant). Such a token reaches the MCP facade and nothing else:
// every other function refuses it BEFORE any privileged client or
// provider call.
//
// Reading the claims without verifying the signature is a refusal
// classifier, not an authorisation: a forged token that claims a client
// is only refused sooner, and a genuine token cannot drop the claim
// without breaking its signature, which the function's own verification
// (auth.getUser, or the gateway) then rejects.

/** The OAuth client a bearer token was issued to, or null. */
export function delegatedClient(authorization: string | null): string | null {
  const token = (authorization ?? "").replace(/^Bearer\s+/i, "");
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const claims = JSON.parse(atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)));
    const client = claims?.client_id;
    return typeof client === "string" && client.length > 0 ? client : null;
  } catch {
    return null;
  }
}

/** A 403 for a delegated token, or null for any other caller. */
export function refuseDelegated(
  req: Request,
  headers: Record<string, string> = {},
): Response | null {
  if (delegatedClient(req.headers.get("Authorization")) === null) return null;
  return new Response(JSON.stringify({ error: "delegated_token_refused" }), {
    status: 403,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}
