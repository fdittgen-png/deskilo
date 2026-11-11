// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3091, GHSA-9525-vh85-5hjg — the scan step names nobody and answers the
// same for every tag; a short UID is refused before the database. How often
// one tag or one source may scan is counted in the database (pgTAP 384).

import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";
import { identifyAnswer, UID_PATTERN } from "./badge_guard.ts";

Deno.test("the scan names nobody and answers the same for every tag", () => {
  const answer = identifyAnswer();
  assertEquals(Object.keys(answer).sort(), [
    "display_name",
    "has_avatar",
    "ok",
    "step",
  ]);
  assertEquals(answer.display_name, "");
  assertEquals(answer.has_avatar, false);
  assertEquals(identifyAnswer(), answer);
});

Deno.test("a UID under eight hex characters is refused", () => {
  assertFalse(UID_PATTERN.test("a1b2"));
  assertFalse(UID_PATTERN.test("a1b2c3d"));
  assertFalse(UID_PATTERN.test("A1B2C3D4"));
  assert(UID_PATTERN.test("a1b2c3d4"));
  assert(UID_PATTERN.test("04a1b2c3d4e5f6"));
});
