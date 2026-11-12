// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The database trigger carries a secret read from Vault. A public API key
// alone never authorizes delivery once the installation has paired its secrets.

export const PUSH_SECRET_HEADER = "x-deskilo-push-secret";

import { sameSecret } from "../_shared/same_secret.ts";

export { sameSecret };

let warned = false;

/** The trigger's secret or the exact service credential, nothing else. An
 * installation without the secret accepts only the service credential and
 * says once per worker that the secret is missing (GHSA-jww4-4f4q-xg4p).
 * A decoded JWT role never proves its signature. */
export function mayTriggerPush(
  req: Request,
  secret: string | undefined,
  serviceKey: string | undefined,
): boolean {
  if (!secret && !warned) {
    warned = true;
    console.error(
      "send-push: PUSH_SHARED_SECRET is not set; only the service credential is accepted",
    );
  }
  const sent = req.headers.get(PUSH_SECRET_HEADER);
  if (secret && sent && sameSecret(sent, secret)) return true;
  const bearer = (req.headers.get("authorization") ?? "").match(/^Bearer\s+(.+)$/i)?.[1];
  return !!(serviceKey && bearer && sameSecret(bearer, serviceKey));
}
