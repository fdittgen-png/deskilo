// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #662 — sign in by scanning an RFID badge. The tag IDENTIFIES, a PIN
// CONFIRMS, and only this function can turn the pair into a session.
//
// WHY HERE AND NOT IN SQL. A database function that mints a login would
// be one `grant` away from being callable by `anon`, and an RFID UID is
// not a secret — it is broadcast to any reader a few centimetres away
// and clonable for about thirty euros. So `badge_auth_verify` is REVOKED
// from public, anon and authenticated (migration 0123), and reachable
// only by the service role that lives in this function's environment.
//
// TWO STEPS, ONE FORM.
//   {uid}        -> the scan. The same answer for every well-formed tag:
//                   nobody is named before the PIN. Counted in the database
//                   per tag and per source (GHSA-9525-vh85-5hjg); past either
//                   ceiling it answers "locked" (wait).
//   {uid, pin}   -> a one-time token the client exchanges for a session
//                   via supabase.auth.verifyOtp. The session is minted by
//                   GoTrue from an e-mail this function never returns.
//
// FAILURES ARE UNIFORM. Unknown tag, disarmed badge, wrong PIN and
// lockout all answer the same way, because telling them apart is how an
// attacker learns which tags are real. The distinction lives in the
// attempt log, which nothing outside the service role can read.

import { createClient } from "npm:@supabase/supabase-js@2";
import { handle } from "./handler.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve((req) =>
  handle(req, {
    rpc: (fn, args) => supabase.rpc(fn, args),
    emailOf: async (userId) => {
      const { data, error } = await supabase.auth.admin.getUserById(userId);
      if (error || !data?.user?.email) {
        console.error("no e-mail for verified badge user", error?.message);
        return null;
      }
      return data.user.email;
    },
    tokenFor: async (email) => {
      const { data, error } = await supabase.auth.admin.generateLink({ type: "magiclink", email });
      if (error || !data?.properties?.hashed_token) {
        console.error("generateLink failed", error?.message);
        return null;
      }
      return data.properties.hashed_token;
    },
  })
);
