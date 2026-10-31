// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The database trigger carries a secret read from Vault. A public API key
// alone never authorizes delivery, even before an installation is configured.

export const PUSH_SECRET_HEADER = "x-deskilo-push-secret";

/** Constant-time equality of two strings. */
export function sameSecret(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

/** Only the configured trigger secret or exact service credential authorizes a call.
 * A decoded JWT role is never proof of its signature. Missing configuration
 * fails closed instead of exposing the notification fanout to publishable keys. */
export function mayTriggerPush(
  req: Request,
  secret: string | undefined,
  serviceKey: string | undefined,
): boolean {
  const sent = req.headers.get(PUSH_SECRET_HEADER);
  if (secret && sent && sameSecret(sent, secret)) return true;
  const bearer = (req.headers.get("authorization") ?? "").match(/^Bearer\s+(.+)$/i)?.[1];
  return !!(serviceKey && bearer && sameSecret(bearer, serviceKey));
}
