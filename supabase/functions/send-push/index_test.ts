// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2020 — bounded push work. Badge counts are read once per distinct
// member (20 members × 3 devices = 20 reads, not 60); a failed count is
// unknown, never a zero badge; the OAuth token is reused until a minute
// before expiry, concurrent callers share one refresh, a rotated key gets
// its own; only FCM's structured UNREGISTERED prunes an endpoint.
// Checkpoint B: recipient reads page until an empty page and throw on a
// failed page; each endpoint gets one finite outcome; Retry-After is
// honoured once when it fits, never slept through; sends are bounded.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  badgeCounts,
  cachedAccessToken,
  classify,
  CONCURRENCY,
  deliverAll,
  dropMuted,
  mutedExceptMentioned,
  isUnregistered,
  readAll,
  resetTokenCacheForTests,
  retryWaitMs,
} from "./index.ts";

function countingSupabase(fail: Set<string> = new Set()) {
  const reads: string[] = [];
  const supabase = {
    from: () => {
      let member = "";
      const chain = {
        select: () => chain,
        eq: (col: string, v: string) => {
          if (col === "subject_member_id") member = v;
          if (col === "status") {
            reads.push(member);
            return Promise.resolve(
              fail.has(member)
                ? { count: null, error: { message: "denied" } }
                : { count: member.length, error: null },
            );
          }
          return chain;
        },
      };
      return chain;
    },
  };
  return { supabase, reads };
}

Deno.test("20 members × 3 devices: 20 badge reads, one per member", async () => {
  const { supabase, reads } = countingSupabase();
  const members = Array.from({ length: 20 }, (_, i) => `member-${i}`);
  const endpoints = members.flatMap((m) => [m, m, m]);
  const badges = await badgeCounts(supabase, endpoints);
  assertEquals(reads.length, 20);
  assertEquals(badges.size, 20);
  assertEquals(badges.get("member-3"), "member-3".length);
});

Deno.test("a failed count is unknown, not a zero badge", async () => {
  const { supabase } = countingSupabase(new Set(["b"]));
  const badges = await badgeCounts(supabase, ["a", "b"]);
  assertEquals(badges.has("b"), false);
  assertEquals(badges.get("a"), 1);
});

const SA = { client_email: "svc@x", private_key: "k".repeat(10), project_id: "p" };

Deno.test("the token is reused until a minute before expiry", async () => {
  resetTokenCacheForTests();
  let mints = 0;
  const mint = () => Promise.resolve(`t${++mints}`);
  let now = 1000;
  assertEquals(await cachedAccessToken(SA, mint, () => now), "t1");
  now += 3000;
  assertEquals(await cachedAccessToken(SA, mint, () => now), "t1");
  now += 500; // within the last minute of 3500 s
  assertEquals(await cachedAccessToken(SA, mint, () => now), "t2");
  assertEquals(mints, 2);
});

Deno.test("concurrent callers share one refresh", async () => {
  resetTokenCacheForTests();
  let mints = 0;
  const mint = () => new Promise<string>((r) => setTimeout(() => r(`t${++mints}`), 5));
  const [a, b] = await Promise.all([
    cachedAccessToken(SA, mint, () => 0),
    cachedAccessToken(SA, mint, () => 0),
  ]);
  assertEquals([a, b, mints], ["t1", "t1", 1]);
});

Deno.test("a rotated key gets its own token; a failed mint is not cached", async () => {
  resetTokenCacheForTests();
  let mints = 0;
  const mint = () => Promise.resolve(`t${++mints}`);
  await cachedAccessToken(SA, mint, () => 0);
  await cachedAccessToken({ ...SA, private_key: "rotated-key" }, mint, () => 0);
  assertEquals(mints, 2);
  resetTokenCacheForTests();
  await assertRejects(() => cachedAccessToken(SA, () => Promise.reject(new Error("x")), () => 0));
  assertEquals(await cachedAccessToken(SA, mint, () => 0), "t3");
});

Deno.test("only the structured UNREGISTERED prunes", () => {
  const unregistered = {
    error: { details: [{ "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError", errorCode: "UNREGISTERED" }] },
  };
  assertEquals(isUnregistered(404, unregistered), true);
  assertEquals(isUnregistered(404, { error: { message: "Requested entity was not found." } }), false);
  assertEquals(isUnregistered(410, null), false);
  assertEquals(isUnregistered(500, unregistered), false);
});

Deno.test("readAll pages past a server cap lower than PAGE until an empty page", async () => {
  const rows = Array.from({ length: 2500 }, (_, i) => i);
  const cap = 400; // the server returns fewer than asked
  const calls: number[] = [];
  const all = await readAll<number>((from, to) => {
    calls.push(from);
    return Promise.resolve({ data: rows.slice(from, Math.min(to + 1, from + cap)), error: null });
  });
  assertEquals(all, rows); // nothing skipped, nothing doubled
  assertEquals(calls.slice(0, 3), [0, cap, 2 * cap]);
});

Deno.test("readAll: a failed page is unknown recipients, never none", async () => {
  await assertRejects(() =>
    readAll((from) =>
      Promise.resolve(from === 0 ? { data: [1], error: null } : { data: null, error: { message: "x" } })
    )
  );
});

Deno.test("classify: each status has one finite outcome", () => {
  const gone = { error: { details: [{ errorCode: "UNREGISTERED" }] } };
  assertEquals(classify(200, {}), "sent");
  assertEquals(classify(404, gone), "unregistered");
  assertEquals(classify(404, null), "rejected"); // generic 404 never prunes
  assertEquals(classify(401, null), "rejected");
  assertEquals(classify(429, null), "retryable");
  assertEquals(classify(503, null), "retryable");
  assertEquals(classify(null, null), "unknown"); // deadline / lost response
});

Deno.test("retryWaitMs honours Retry-After only when it fits", () => {
  assertEquals(retryWaitMs(null), 1000);
  assertEquals(retryWaitMs("2"), 2000);
  assertEquals(retryWaitMs("60"), null);
  assertEquals(retryWaitMs("soon"), null);
});

Deno.test("deliverAll: one retry after Retry-After, no resend of unknown, bounded fan-out", async () => {
  const eps = Array.from({ length: 25 }, (_, i) => i);
  const sends = new Map<number, number>();
  const waits: number[] = [];
  let inFlight = 0;
  let peak = 0;
  const out = await deliverAll(eps, async (ep) => {
    sends.set(ep, (sends.get(ep) ?? 0) + 1);
    inFlight++;
    peak = Math.max(peak, inFlight);
    await new Promise((r) => setTimeout(r, 1));
    inFlight--;
    if (ep === 1) return { status: sends.get(ep) === 1 ? 429 : 200, body: null, retryAfter: "2" };
    if (ep === 2) return { status: 429, body: null, retryAfter: "120" };
    if (ep === 3) return { status: null, body: null, retryAfter: null };
    return { status: 200, body: null, retryAfter: null };
  }, (ms) => {
    waits.push(ms);
    return Promise.resolve();
  });
  const by = new Map(out.map((r) => [r.ep, r.outcome]));
  assertEquals([by.get(1), by.get(2), by.get(3), by.get(4)], ["sent", "retryable", "unknown", "sent"]);
  assertEquals([sends.get(1), sends.get(2), sends.get(3)], [2, 1, 1]);
  assertEquals(waits, [2000]);
  assertEquals(out.length, 25);
  assertEquals(peak <= CONCURRENCY, true);
});

Deno.test("a muted conversation does not ring for the member who muted it (#2216)", () => {
  const all = [{ id: "a" }, { id: "b" }, { id: "c" }];
  assertEquals(dropMuted(all, ["b"]), [{ id: "a" }, { id: "c" }]);
  assertEquals(dropMuted(all, []), all);
  assertEquals(dropMuted(all, ["a", "b", "c"]), []);
});

Deno.test("#2216 — a mention rings through a mute; the rest stays silent", () => {
  const all = [{ id: "a" }, { id: "b" }, { id: "c" }];
  // b and c muted the conversation; the message mentions c.
  const muted = mutedExceptMentioned(["b", "c"], ["c"]);
  assertEquals(muted, ["b"]);
  assertEquals(dropMuted(all, muted), [{ id: "a" }, { id: "c" }]);
  // No mention: every mute holds.
  assertEquals(mutedExceptMentioned(["b", "c"], []), ["b", "c"]);
});

