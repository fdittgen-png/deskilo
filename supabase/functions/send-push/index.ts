// SPDX-License-Identifier: AGPL-3.0-or-later
//
// FCM fanout (#426): the 0084 events trigger POSTs {event_id} here; this
// function loads the event ITSELF with the service role and computes the
// recipients — the caller is never trusted with recipients or content, so
// a spoofed call can at worst re-announce a real event. UnifiedPush
// endpoints are still POSTed directly from the trigger; this function
// handles the fcm:<token> rows, which need an OAuth2-signed FCM v1 call
// pg_net cannot make.
//
// Secrets: FCM_SERVICE_ACCOUNT — the Firebase service-account JSON
// (docs/guides/push-setup.md). Absent -> the function no-ops politely so
// the trigger never fails.

import { refuseDelegated } from "../_shared/delegated.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

// Built on first use (not at import), so the helpers can be tested.
let client: SupabaseClient | null = null;
const db = (): SupabaseClient =>
  client ??= createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

// Generic English notification text per kind (the 0012 privacy doctrine:
// no names, no times; a foregrounded app replaces this with its own
// localized notification).
const TEXTS: Record<string, { title: string; body: string }> = {
  pending_request: {
    title: "DesKilo",
    body: "Someone needs your confirmation.",
  },
  reservation_cancelled: {
    title: "Reservation removed",
    body: "A reservation was removed by an admin.",
  },
  member_note: {
    title: "DesKilo",
    body: "You have a new message.",
  },
  // #726 — automatic dunning: the subject member, nobody else.
  invoice_reminder: {
    title: "DesKilo",
    body: "A payment reminder is waiting for you.",
  },
};

/** #2020 — every request to Google has a deadline that covers the body
 * too (the abort also ends a stalled body read). */
export const FETCH_DEADLINE_MS = 10_000;

/** #2020 — FCM v1 says a registration is gone with the structured
 * `UNREGISTERED` error code. Only that prunes an endpoint: a bare 404 or
 * 410 can be a wrong project or route, and must not wipe valid tokens. */
export function isUnregistered(status: number, body: unknown): boolean {
  if (status !== 404 && status !== 410 && status !== 400) return false;
  const details = (body as { error?: { details?: unknown[] } })?.error?.details;
  return Array.isArray(details) &&
    details.some((d) => (d as { errorCode?: string })?.errorCode === "UNREGISTERED");
}

/** #2020 — the pending-validation badge, ONCE per distinct member (was
 * once per device). A failed count is unknown, not zero: the member is
 * left out of the map and the message carries no badge. */
export async function badgeCounts(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  memberIds: string[],
): Promise<Map<string, number>> {
  const out = new Map<string, number>();
  for (const id of new Set(memberIds)) {
    const { count, error } = await supabase
      .from("events")
      .select("id", { count: "exact", head: true })
      .eq("subject_member_id", id)
      .eq("status", "pending");
    if (!error && typeof count === "number") out.set(id, count);
  }
  return out;
}

/** #2020 — the OAuth token, reused within this worker until a minute
 * before it expires; concurrent callers share one refresh. Keyed by the
 * service account, so a rotated credential never reuses the old token. */
const tokenCache = new Map<string, Promise<{ token: string; expiresAt: number }>>();

export async function cachedAccessToken(
  sa: { client_email: string; private_key: string; project_id?: string },
  mint: typeof fcmAccessToken = fcmAccessToken,
  nowS: () => number = () => Date.now() / 1000,
): Promise<string> {
  const key = `${sa.project_id ?? ""}|${sa.client_email}|${sa.private_key.length}`;
  const cached = tokenCache.get(key);
  if (cached) {
    try {
      const { token, expiresAt } = await cached;
      if (expiresAt - 60 > nowS()) return token;
    } catch {
      // A failed refresh is retried below, not reused.
    }
  }
  const pending = mint(sa).then((token) => ({ token, expiresAt: nowS() + 3500 }));
  tokenCache.set(key, pending);
  try {
    return (await pending).token;
  } catch (e) {
    tokenCache.delete(key);
    throw e;
  }
}

export function resetTokenCacheForTests() {
  tokenCache.clear();
}

export async function fcmAccessToken(sa: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const enc = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_")
      .replace(/=+$/, "");
  const unsigned = `${enc(header)}.${enc(claims)}`;
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${unsigned}.${sigB64}`,
    signal: AbortSignal.timeout(FETCH_DEADLINE_MS),
  });
  // The body is not logged: it can echo credential details.
  if (!res.ok) throw new Error(`token exchange failed: HTTP ${res.status}`);
  return (await res.json()).access_token as string;
}

export async function handle(req: Request): Promise<Response> {
  const supabase = db();
  // #1614 — system-only: a delegated (MCP) token never triggers a push.
  const delegated = refuseDelegated(req);
  if (delegated) return delegated;
  const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!saRaw) {
    return Response.json({ skipped: "FCM_SERVICE_ACCOUNT not set" });
  }
  const sa = JSON.parse(saRaw);

  const { event_id, note_id } = await req.json().catch(() => ({}));
  if (!event_id && !note_id) {
    return Response.json({ error: "event_id or note_id required" }, { status: 400 });
  }

  let kind: string;
  let recipients: { id: string }[];
  if (note_id) {
    // Member note (#456): load it ourselves — recipient is the target;
    // a GROUP message (#1822) goes to the conversation's current
    // participants except the sender, never to the admins; only the
    // legacy broadcast (no conversation, no target) fans out to every
    // active admin/owner except the sender.
    const { data: note } = await supabase
      .from("member_notes")
      .select("id, workspace_id, from_member_id, to_member_id, conversation_id")
      .eq("id", note_id)
      .maybeSingle();
    if (!note) return Response.json({ error: "unknown note" }, { status: 404 });
    kind = "member_note";
    if (note.to_member_id) {
      recipients = [{ id: note.to_member_id }];
    } else if (note.conversation_id) {
      const { data: participants } = await supabase
        .from("conversation_participants")
        .select("member_id")
        .eq("conversation_id", note.conversation_id)
        .is("left_at", null)
        .neq("member_id", note.from_member_id);
      recipients = (participants ?? []).map((p) => ({ id: p.member_id }));
    } else {
      const { data: admins } = await supabase
        .from("members")
        .select("id, is_admin, is_owner")
        .eq("workspace_id", note.workspace_id)
        .eq("status", "active")
        .neq("id", note.from_member_id);
      recipients = (admins ?? []).filter((m) => m.is_admin || m.is_owner);
    }
  } else {
    // Load the event ourselves — never trust the caller's content.
    const { data: event } = await supabase
      .from("events")
      .select("id, workspace_id, type, action, status, actor_member_id, subject_member_id")
      .eq("id", event_id)
      .maybeSingle();
    if (!event) return Response.json({ error: "unknown event" }, { status: 404 });

    const eventKind = event.status === "pending"
      ? "pending_request"
      : event.type === "reservation" && event.action === "cancelled"
      ? "reservation_cancelled"
      : event.type === "invoice_reminder"
      ? "invoice_reminder"
      : null;
    if (!eventKind) return Response.json({ skipped: "kind not pushed" });
    kind = eventKind;

    // Recipients — the 0082 rules, re-derived here for fcm rows.
    const { data: members } = await supabase
      .from("members")
      .select("id, is_admin, is_owner")
      .eq("workspace_id", event.workspace_id)
      .eq("status", "active")
      .neq("id", event.actor_member_id);
    recipients = (members ?? []).filter((m) =>
      kind === "reservation_cancelled"
        ? m.id === event.subject_member_id || m.is_admin || m.is_owner
        : m.id === event.subject_member_id
    );
    // The sweep acts AS the owner; a reminder for the owner's own
    // invoice must still reach them.
    if (kind === "invoice_reminder" && recipients.length === 0) {
      recipients = [{ id: event.subject_member_id }];
    }
  }
  if (recipients.length === 0) return Response.json({ sent: 0 });

  const { data: endpoints } = await supabase
    .from("push_endpoints")
    .select("member_id, endpoint")
    .in("member_id", recipients.map((m) => m.id))
    .like("endpoint", "fcm:%");
  if (!endpoints || endpoints.length === 0) return Response.json({ sent: 0 });

  const token = await cachedAccessToken(sa);
  const text = TEXTS[kind];
  // iOS/macOS badge: each recipient's live pending count, once per member.
  const badges = await badgeCounts(supabase, endpoints.map((ep) => ep.member_id));
  let sent = 0;
  let failed = 0;
  for (const ep of endpoints) {
    const badge = badges.get(ep.member_id);
    const message = {
      message: {
        token: ep.endpoint.slice(4),
        notification: { title: text.title, body: text.body },
        data: { kind },
        ...(badge === undefined ? {} : { apns: { payload: { aps: { badge } } } }),
      },
    };
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(message),
        signal: AbortSignal.timeout(FETCH_DEADLINE_MS),
      },
    ).catch(() => null);
    if (res?.ok) {
      sent++;
      continue;
    }
    failed++;
    if (!res) continue; // deadline or network: outcome unknown, kept
    const body = await res.json().catch(() => null);
    if (isUnregistered(res.status, body)) {
      // A registration FCM says is gone: prune exactly that endpoint.
      await supabase.from("push_endpoints").delete().eq("endpoint", ep.endpoint);
    }
  }
  return Response.json({ sent, failed });
}

if (import.meta.main) Deno.serve(handle);
