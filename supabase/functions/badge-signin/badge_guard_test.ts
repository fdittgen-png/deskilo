// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3091 — the identify step never names the account, a short UID is refused
// before the database, and one caller cannot scan without limit.

import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";
import { identifyAnswer, IdentifyLimiter, UID_PATTERN } from "./badge_guard.ts";

Deno.test("identify carries no user id, whatever the database returned", () => {
  const answer = identifyAnswer({
    display_name: "Ada",
    has_avatar: true,
    // deno-lint-ignore no-explicit-any
    ...({ user_id: "u-1", email: "a@b.c" } as any),
  });
  assertEquals(Object.keys(answer).sort(), [
    "display_name",
    "has_avatar",
    "ok",
    "step",
  ]);
  assertEquals(answer.display_name, "Ada");
});

Deno.test("a UID under eight hex characters is refused", () => {
  assertFalse(UID_PATTERN.test("a1b2"));
  assertFalse(UID_PATTERN.test("a1b2c3d"));
  assertFalse(UID_PATTERN.test("A1B2C3D4"));
  assert(UID_PATTERN.test("a1b2c3d4"));
  assert(UID_PATTERN.test("04a1b2c3d4e5f6"));
});

Deno.test("one caller is limited, another is not, and the window slides", () => {
  let now = 0;
  const limiter = new IdentifyLimiter(3, 1000, () => now);
  assert(limiter.allow("a"));
  assert(limiter.allow("a"));
  assert(limiter.allow("a"));
  assertFalse(limiter.allow("a"));
  assert(limiter.allow("b"));
  now = 1001;
  assert(limiter.allow("a"));
});
