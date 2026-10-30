// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3092 — who may ask send-push to ring someone. The database triggers call
// it with the publishable (anon) key, which anyone holding the app can read:
// without a check of its own, that key re-sends real notifications and tells
// the caller which ids exist. With PUSH_SHARED_SECRET set, a call must carry
// it (header `x-deskilo-push-secret`, held by the trigger in Vault) or a
// service-role JWT; anything else is refused before the body is read.
//
// Rollout: until the operator sets PUSH_SHARED_SECRET the function behaves as
// before (and says so in its log), so the order of the two deployment steps
// — function first, then the trigger's header — cannot break delivery.

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

/** The `role` claim of a bearer JWT (the gateway has verified its
 * signature); null when it is not a JWT. */
export function bearerRole(req: Request): string | null {
  const bearer = (req.headers.get("authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  const payload = bearer.split(".")[1];
  if (!payload) return null;
  try {
    const json = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
    const claims = JSON.parse(json);
    return typeof claims.role === "string" ? claims.role : null;
  } catch {
    return null;
  }
}

let warned = false;

/** Whether [req] may trigger a push, given the operator's [secret]. */
export function mayTriggerPush(
  req: Request,
  secret: string | undefined,
): boolean {
  if (!secret) {
    if (!warned) {
      warned = true;
      console.warn(
        "send-push: PUSH_SHARED_SECRET is not set — any holder of the " +
          "publishable key can trigger a push (#3092)",
      );
    }
    return true;
  }
  const sent = req.headers.get(PUSH_SECRET_HEADER);
  if (sent && sameSecret(sent, secret)) return true;
  return bearerRole(req) === "service_role";
}
