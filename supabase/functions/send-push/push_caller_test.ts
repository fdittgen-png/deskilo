// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Configured installations accept only their trigger secret or exact service
// credential, while unconfigured installations retain legacy delivery.
import { assert, assertFalse } from "jsr:@std/assert@1";
import { mayTriggerPush, PUSH_SECRET_HEADER, sameSecret } from "./push_caller.ts";
const req = (headers: Record<string, string>) =>
  new Request("https://f.test/send-push", { method: "POST", headers });
const allowed = (headers: Record<string, string>, secret: string | undefined = "trigger") =>
  mayTriggerPush(req(headers), secret, "exact-service-key");
Deno.test("public, missing, wrong and role-forged credentials are refused", () => {
  assertFalse(allowed({}));
  assertFalse(allowed({ [PUSH_SECRET_HEADER]: "wrong" }));
  assertFalse(allowed({ authorization: "Bearer publishable-key" }));
  const forged = `h.${btoa(JSON.stringify({ role: "service_role" }))}.signature`;
  assertFalse(allowed({ authorization: `Bearer ${forged}` }));
});
Deno.test("the trigger secret and exact service credential are accepted", () => {
  assert(allowed({ [PUSH_SECRET_HEADER]: "trigger" }));
  assert(allowed({ authorization: "Bearer exact-service-key" }));
  assert(allowed({ authorization: "Bearer exact-service-key" }, undefined));
});
Deno.test("unconfigured installations retain delivery until secrets are paired", () => {
  assert(mayTriggerPush(req({}), undefined, undefined));
  assert(mayTriggerPush(req({ authorization: "Bearer publishable-key" }), "", undefined));
});
Deno.test("secret comparison includes every byte and its length", () => {
  assert(sameSecret("abc", "abc"));
  assertFalse(sameSecret("abc", "abd"));
  assertFalse(sameSecret("abc", "abcd"));
  assertFalse(sameSecret("", "x"));
});
