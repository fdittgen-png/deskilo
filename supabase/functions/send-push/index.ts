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

/** #2020 — a read that is complete whatever the server's row cap: pages
 * of [PAGE] rows until an EMPTY page (a short page can be the cap, not
 * the end). A failed page throws — recipients are unknown, never none. */
export const PAGE = 1000;

export async function readAll<T>(
  page: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: unknown }>,
): Promise<T[]> {
  const out: T[] = [];
  // The next page starts after what was RECEIVED, so a cap below PAGE
  // skips nothing.
  for (;;) {
    const from = out.length;
    const { data, error } = await page(from, from + PAGE - 1);
    if (error) throw new Error("recipient query failed");
    if (!data || data.length === 0) return out;
    out.push(...data);
  }
}

export function chunked<T>(items: T[], size = 100): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

/** #2020 — one finite outcome per endpoint. No response (deadline,
 * network) is unknown: FCM may have delivered it, so it is not resent. */
export type Outcome = "sent" | "unregistered" | "retryable" | "rejected" | "unknown";

export function classify(status: number | null, body: unknown): Outcome {
  if (status === null) return "unknown";
  if (status >= 200 && status < 300) return "sent";
  if (isUnregistered(status, body)) return "unregistered";
  if (status === 429 || status >= 500) return "retryable";
  return "rejected";
}

/** #2020 — at most one retry, and only when the wait fits the call:
 * Retry-After in seconds (default 1 s), capped at [MAX_RETRY_WAIT_MS];
 * a longer wait is reported retryable instead of slept through. */
export const MAX_RETRY_WAIT_MS = 5_000;

export function retryWaitMs(retryAfter: string | null): number | null {
  const s = retryAfter === null ? 1 : Number(retryAfter);
  if (!Number.isFinite(s) || s < 0) return null;
  const ms = s * 1000;
  return ms <= MAX_RETRY_WAIT_MS ? ms : null;
}

/** #2020 — sends to every endpoint, [CONCURRENCY] at a time. */
export const CONCURRENCY = 10;

export async function deliverAll<E>(
  endpoints: E[],
  send: (ep: E) => Promise<{ status: number | null; body: unknown; retryAfter: string | null }>,
  sleep: (ms: number) => Promise<void> = (ms) => new Promise((r) => setTimeout(r, ms)),
): Promise<{ ep: E; outcome: Outcome }[]> {
  const out: { ep: E; outcome: Outcome }[] = [];
  for (const batch of chunked(endpoints, CONCURRENCY)) {
    out.push(...await Promise.all(batch.map(async (ep) => {
      let r = await send(ep);
      let outcome = classify(r.status, r.body);
      const wait = outcome === "retryable" ? retryWaitMs(r.retryAfter) : null;
      if (wait !== null) {
        await sleep(wait);
        r = await send(ep);
        outcome = classify(r.status, r.body);
      }
      return { ep, outcome };
    })));
  }
  return out;
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
  try {
    return await deliver(req);
  } catch (e) {
    if ((e as Error).message !== "recipient query failed") throw e;
    return Response.json({ error: "recipients unknown" }, { status: 502 });
  }
}

async function deliver(req: Request): Promise<Response> {
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
      const participants = await readAll<{ member_id: string }>((from, to) =>
        supabase
          .from("conversation_participants")
          .select("member_id")
          .eq("conversation_id", note.conversation_id)
          .is("left_at", null)
          .neq("member_id", note.from_member_id)
          .order("member_id")
          .range(from, to)
      );
      recipients = participants.map((p) => ({ id: p.member_id }));
    } else {
      const admins = await readAll<{ id: string; is_admin: boolean; is_owner: boolean }>(
        (from, to) =>
          supabase
            .from("members")
            .select("id, is_admin, is_owner")
            .eq("workspace_id", note.workspace_id)
            .eq("status", "active")
            .neq("id", note.from_member_id)
            .order("id")
            .range(from, to),
      );
      recipients = admins.filter((m) => m.is_admin || m.is_owner);
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
    const members = await readAll<{ id: string; is_admin: boolean; is_owner: boolean }>(
      (from, to) =>
        supabase
          .from("members")
          .select("id, is_admin, is_owner")
          .eq("workspace_id", event.workspace_id)
          .eq("status", "active")
          .neq("id", event.actor_member_id)
          .order("id")
          .range(from, to),
    );
    recipients = members.filter((m) =>
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

  const endpoints: { member_id: string; endpoint: string }[] = [];
  for (const ids of chunked(recipients.map((m) => m.id))) {
    endpoints.push(
      ...await readAll<{ member_id: string; endpoint: string }>((from, to) =>
        supabase
          .from("push_endpoints")
          .select("member_id, endpoint")
          .in("member_id", ids)
          .like("endpoint", "fcm:%")
          .order("endpoint")
          .range(from, to)
      ),
    );
  }
  if (endpoints.length === 0) return Response.json({ sent: 0 });

  const token = await cachedAccessToken(sa);
  const text = TEXTS[kind];
  // iOS/macOS badge: each recipient's live pending count, once per member.
  const badges = await badgeCounts(supabase, endpoints.map((ep) => ep.member_id));
  const results = await deliverAll(endpoints, async (ep) => {
    const badge = badges.get(ep.member_id);
    const message = {
      message: {
        token: ep.endpoint.slice(4),
        notification: { title: text.title, body: text.body },
        data: { kind },
        ...(badge === undefined ? {} : { apns: { payload: { aps: { badge } } } }),
      },
    };
    try {
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
      );
      // The same signal bounds the body read: a stalled body is unknown.
      const body = await res.json().catch(() => null);
      return { status: res.status, body, retryAfter: res.headers.get("retry-after") };
    } catch {
      return { status: null, body: null, retryAfter: null };
    }
  });
  const tally: Record<Outcome, number> = {
    sent: 0,
    unregistered: 0,
    retryable: 0,
    rejected: 0,
    unknown: 0,
  };
  for (const { ep, outcome } of results) {
    tally[outcome]++;
    // A registration FCM says is gone: prune exactly that endpoint.
    if (outcome === "unregistered") {
      await supabase.from("push_endpoints").delete().eq("endpoint", ep.endpoint);
    }
  }
  return Response.json({ ...tally, failed: results.length - tally.sent });
}

if (import.meta.main) Deno.serve(handle);
