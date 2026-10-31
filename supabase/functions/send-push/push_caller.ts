// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The database trigger carries a secret read from Vault. A public API key
// alone never authorizes delivery once the installation has paired its secrets.

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

let warned = false;

/** Configured installations accept only the trigger or exact service credential.
 * Unconfigured installations retain delivery during the operator rollout and
 * warn once per worker. A decoded JWT role never proves its signature. */
export function mayTriggerPush(
  req: Request,
  secret: string | undefined,
  serviceKey: string | undefined,
): boolean {
  if (!secret) {
    if (!warned) {
      warned = true;
      console.warn("send-push: PUSH_SHARED_SECRET is not set; legacy caller access remains enabled");
    }
    return true;
  }
  const sent = req.headers.get(PUSH_SECRET_HEADER);
  if (secret && sent && sameSecret(sent, secret)) return true;
  const bearer = (req.headers.get("authorization") ?? "").match(/^Bearer\s+(.+)$/i)?.[1];
  return !!(serviceKey && bearer && sameSecret(bearer, serviceKey));
}
