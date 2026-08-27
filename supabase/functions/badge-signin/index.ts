// SPDX-License-Identifier: 0BSD
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
//   {uid}        -> who is this? display name + avatar flag. No e-mail,
//                   no attempt consumed: a fumbled scan must not lock a
//                   member out before they have typed anything.
//   {uid, pin}   -> a one-time token the client exchanges for a session
//                   via supabase.auth.verifyOtp. The session is minted by
//                   GoTrue from an e-mail this function never returns.
//
// FAILURES ARE UNIFORM. Unknown tag, disarmed badge, wrong PIN and
// lockout all answer the same way, because telling them apart is how an
// attacker learns which tags are real. The distinction lives in the
// attempt log, which nothing outside the service role can read.

import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

/// The single refusal. Deliberately says nothing about WHY — see the
/// header. `locked` is separated only so the client can tell the member
/// to wait rather than keep trying; it reveals nothing about the tag,
/// because a lockout is reported for unknown tags too.
function refused(reason: "refused" | "locked"): Response {
  return json({ ok: false, reason }, 200);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ ok: false, reason: "refused" }, 405);

  let uid: string | undefined;
  let pin: string | undefined;
  try {
    const body = await req.json();
    uid = typeof body?.uid === "string" ? body.uid.trim() : undefined;
    pin = typeof body?.pin === "string" ? body.pin.trim() : undefined;
  } catch (_) {
    return refused("refused");
  }
  // A UID is lowercase hex without separators — the same normalization
  // register_nfc_badge applies. Reject anything else before it reaches
  // the database rather than hashing arbitrary input.
  if (!uid || !/^[0-9a-f]{4,64}$/.test(uid)) return refused("refused");
  if (pin !== undefined && !/^[0-9]{4,8}$/.test(pin)) return refused("refused");

  const { data, error } = await supabase.rpc("badge_auth_verify", {
    p_uid: uid,
    p_pin: pin ?? null,
  });
  if (error) {
    console.error("badge_auth_verify failed", error.message);
    return refused("refused");
  }
  if (!data?.ok) return refused(data?.reason === "locked" ? "locked" : "refused");

  // IDENTIFY — hand back just enough for the form to say whose PIN it is
  // asking for. Never the e-mail: that would make a scanned tag a way to
  // harvest addresses.
  if (pin === undefined) {
    return json({
      ok: true,
      step: "identify",
      display_name: data.display_name ?? "",
      has_avatar: data.has_avatar === true,
      user_id: data.user_id,
    });
  }

  // AUTHENTICATE — the PIN matched. Turn the verified user into a
  // one-time link and return only its token hash; the client exchanges
  // that for a session itself, so no access token is ever assembled here.
  const { data: userData, error: userError } =
    await supabase.auth.admin.getUserById(data.user_id);
  if (userError || !userData?.user?.email) {
    console.error("no e-mail for verified badge user", userError?.message);
    return refused("refused");
  }

  const { data: link, error: linkError } = await supabase.auth.admin.generateLink({
    type: "magiclink",
    email: userData.user.email,
  });
  if (linkError || !link?.properties?.hashed_token) {
    console.error("generateLink failed", linkError?.message);
    return refused("refused");
  }

  return json({
    ok: true,
    step: "authenticate",
    // Exchanged client-side with verifyOtp({ type: 'email', token_hash }).
    token_hash: link.properties.hashed_token,
  });
});
