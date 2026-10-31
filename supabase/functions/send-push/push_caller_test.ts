// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3092 — the caller check: with the secret configured, only the trigger
// (secret header) or the service role may ask for a push; with none
// configured the function keeps working as before.

import { assert, assertFalse } from "jsr:@std/assert@1";
import {
  bearerRole,
  mayTriggerPush,
  PUSH_SECRET_HEADER,
  sameSecret,
} from "./push_caller.ts";

const jwt = (role: string) =>
  `h.${btoa(JSON.stringify({ role })).replace(/=+$/, "")}.s`;
const req = (headers: Record<string, string>) =>
  new Request("https://f.test/send-push", { method: "POST", headers });

Deno.test("a call without the secret is refused when one is configured", () => {
  assertFalse(mayTriggerPush(req({}), "s3cret"));
  assertFalse(
    mayTriggerPush(req({ authorization: `Bearer ${jwt("anon")}` }), "s3cret"),
  );
  assertFalse(mayTriggerPush(req({ [PUSH_SECRET_HEADER]: "wrong" }), "s3cret"));
});

Deno.test("the trigger's secret and the service role are let through", () => {
  assert(mayTriggerPush(req({ [PUSH_SECRET_HEADER]: "s3cret" }), "s3cret"));
  assert(
    mayTriggerPush(
      req({ authorization: `Bearer ${jwt("service_role")}` }),
      "s3cret",
    ),
  );
});

Deno.test("with no secret configured the function keeps working as before", () => {
  assert(
    mayTriggerPush(req({ authorization: `Bearer ${jwt("anon")}` }), undefined),
  );
  assert(mayTriggerPush(req({}), ""));
});

Deno.test("helpers", () => {
  assert(sameSecret("abc", "abc"));
  assertFalse(sameSecret("abc", "abd"));
  assertFalse(sameSecret("abc", "abcd"));
  assertFalse(sameSecret("", "x"));
  assert(
    bearerRole(req({ authorization: `Bearer ${jwt("anon")}` })) === "anon",
  );
  assert(bearerRole(req({ authorization: "Bearer not-a-jwt" })) === null);
});
