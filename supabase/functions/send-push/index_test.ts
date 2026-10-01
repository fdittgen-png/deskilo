// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2020 — bounded push work. Badge counts are read once per distinct
// member (20 members × 3 devices = 20 reads, not 60); a failed count is
// unknown, never a zero badge; the OAuth token is reused until a minute
// before expiry, concurrent callers share one refresh, a rotated key gets
// its own; only FCM's structured UNREGISTERED prunes an endpoint.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  badgeCounts,
  cachedAccessToken,
  isUnregistered,
  resetTokenCacheForTests,
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
