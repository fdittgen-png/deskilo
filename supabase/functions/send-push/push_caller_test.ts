// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Configured installations accept only their trigger secret or exact service
// credential; an installation without the secret accepts only the service
// credential (GHSA-jww4-4f4q-xg4p).
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
Deno.test("without the secret, only the exact service credential is accepted", () => {
  assertFalse(mayTriggerPush(req({}), undefined, undefined));
  assertFalse(mayTriggerPush(req({}), undefined, "exact-service-key"));
  assertFalse(mayTriggerPush(req({ authorization: "Bearer publishable-key" }), "", "exact-service-key"));
  assertFalse(mayTriggerPush(req({ [PUSH_SECRET_HEADER]: "anything" }), "", "exact-service-key"));
  assert(mayTriggerPush(req({ authorization: "Bearer exact-service-key" }), "", "exact-service-key"));
});
Deno.test("secret comparison includes every byte and its length", () => {
  assert(sameSecret("abc", "abc"));
  assertFalse(sameSecret("abc", "abd"));
  assertFalse(sameSecret("abc", "abcd"));
  assertFalse(sameSecret("", "x"));
});
