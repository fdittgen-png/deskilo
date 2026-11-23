// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2354 — what VIES answers becomes one of three outcomes, and an outage
// is never mistaken for a verdict: a reverse charge waits for `valid`.
import { assertEquals } from "jsr:@std/assert@1";
import { askVies } from "./index.ts";

const subject = {
  vat_id: "DE123456789",
  country_code: "DE",
  number: "123456789",
  requester_country: "FR",
  requester_number: "12345678901",
};

const answering = (status: number, body: unknown, seen?: unknown[]) =>
  ((_url: string | URL | Request, init?: RequestInit) => {
    seen?.push(JSON.parse(String(init?.body)));
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  }) as typeof fetch;

Deno.test("a valid number keeps its consultation number", async () => {
  const seen: unknown[] = [];
  const outcome = await askVies(subject, answering(200, {
    valid: true,
    requestIdentifier: "WAPIAAAAZ1",
  }, seen));
  assertEquals(outcome, { status: "valid", consultation: "WAPIAAAAZ1", detail: "" });
  assertEquals(seen[0], {
    countryCode: "DE",
    vatNumber: "123456789",
    requesterMemberStateCode: "FR",
    requesterNumber: "12345678901",
  });
});

Deno.test("an invalid number is a verdict", async () => {
  const outcome = await askVies(subject, answering(200, { valid: false, requestIdentifier: "" }));
  assertEquals(outcome.status, "invalid");
});

Deno.test("a member state that does not answer is an outage", async () => {
  const outcome = await askVies(subject, answering(200, {
    actionSucceed: false,
    errorWrappers: [{ error: "MS_UNAVAILABLE" }],
  }));
  assertEquals(outcome, { status: "unavailable", consultation: "", detail: "MS_UNAVAILABLE" });
});

Deno.test("no answer at all is an outage, not an exception", async () => {
  const outcome = await askVies(subject, (() => Promise.reject(new Error("down"))) as typeof fetch);
  assertEquals(outcome.status, "unavailable");
});

// #4412 -- an uncaught error is the envelope: a code and the request id, never the error's own words.
import { guard } from "../_shared/serve.ts";
import { handle } from "./index.ts";

Deno.test("#4412 vies-check: a thrown error answers the envelope and no internal message", async () => {
  Deno.env.delete("SUPABASE_URL");
  const saved = console.error;
  console.error = () => {};
  try {
    const answer = await guard("vies-check", handle)(
      new Request("https://x.test/", {
        method: "POST",
        headers: { "x-request-id": "r-vies" },
        body: JSON.stringify({ workspace_id: "w", member_id: "m" }),
      }),
    );
    assertEquals(answer.status, 500);
    const text = await answer.text();
    assertEquals(JSON.parse(text), { error: "internal_error", request_id: "r-vies" });
    assertEquals(/supabase|url/i.test(text), false);
  } finally {
    console.error = saved;
  }
});
