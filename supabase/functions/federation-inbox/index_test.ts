// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2b — the inbox carries the request into the database unchanged:
// the raw body bytes (base64, byte for byte), only the envelope headers and
// the function's own path; it decides nothing itself. The database's
// outcome becomes the HTTP status the sending home acts on (2xx done, 401
// retried, other 4xx final), and anything unknown or failed is a 500,
// never a 2xx. The signature, digest, replay and expiry rules themselves are
// proved in the database (pgTAP 272).
import { assertEquals } from "jsr:@std/assert@1";
import { handle, MAX_BODY_BYTES, serve } from "./index.ts";

type Result = { data: unknown; error: { message: string } | null };

function fakeAdmin(result: Result) {
  const calls: { name: string; args: Record<string, unknown> }[] = [];
  const admin = {
    rpc(name: string, args: Record<string, unknown>) {
      calls.push({ name, args });
      return Promise.resolve(result);
    },
  };
  return { admin, calls };
}

async function post(
  fake: ReturnType<typeof fakeAdmin>,
  body: BodyInit | null,
  opts: { method?: string; url?: string; headers?: Record<string, string> } = {},
) {
  const req = new Request(opts.url ?? "http://x/federation-inbox", {
    method: opts.method ?? "POST",
    body,
    headers: opts.headers,
  });
  // deno-lint-ignore no-explicit-any
  const res = await handle(req, { admin: () => fake.admin as any });
  return { status: res.status, body: await res.json() };
}

Deno.test("the raw bytes, the envelope and the own path reach the database", async () => {
  const fake = fakeAdmin({ data: { outcome: "applied" }, error: null });
  // Non-ASCII and key order that a JSON round trip would not keep.
  const raw = '{"b": 1,  "a": "é"}';
  const res = await post(fake, raw, {
    url: "http://x/functions/v1/federation-inbox",
    headers: {
      "x-deskilo-event": "e-1",
      "x-deskilo-signature": "ab",
      "authorization": "Bearer someone",
      "cookie": "c=1",
    },
  });
  assertEquals(res.status, 200);
  assertEquals(fake.calls.length, 1);
  const { name, args } = fake.calls[0];
  assertEquals(name, "federation_inbox_accept");
  assertEquals(args.p_method, "POST");
  assertEquals(args.p_path, "/federation-inbox");
  assertEquals(args.p_headers, { "x-deskilo-event": "e-1", "x-deskilo-signature": "ab" });
  const sent = Uint8Array.from(atob(args.p_body_b64 as string), (c) => c.charCodeAt(0));
  assertEquals(sent, new TextEncoder().encode(raw));
});

for (
  const [outcome, status] of [
    ["applied", 200],
    ["renewed", 200],
    ["staged", 200],
    ["reconciled", 200],
    ["duplicate", 200],
    ["superseded", 200],
    ["held", 200],
    ["unauthorized", 401],
    ["bad_digest", 400],
    ["event_conflict", 409],
    ["revision_conflict", 409],
    ["snapshot_conflict", 409],
    ["future_request", 422],
    ["stale_request", 422],
    ["expired_assertion", 422],
    ["future_assertion", 422],
    ["unlinked_subject", 422],
    ["foreign_workspace", 422],
    ["unenrolled_source", 422],
    ["unverified", 422],
    ["expired_snapshot", 422],
  ] as const
) {
  Deno.test(`the outcome ${outcome} answers ${status}`, async () => {
    const res = await post(fakeAdmin({ data: { outcome }, error: null }), "{}");
    assertEquals(res.status, status);
    assertEquals(res.body.outcome, outcome);
  });
}

Deno.test("an outcome the inbox does not know is not a success", async () => {
  for (const outcome of ["bad_signature", "unknown_installation", "unknown_key", "wrong_target"]) {
    const res = await post(fakeAdmin({ data: { outcome }, error: null }), "{}");
    assertEquals(res.status >= 400, true);
  }
});

Deno.test("a database failure is a 500 the sender retries", async () => {
  const res = await post(fakeAdmin({ data: null, error: { message: "down" } }), "{}");
  assertEquals(res.status, 500);
});

Deno.test("an unknown outcome is never a success", async () => {
  const res = await post(fakeAdmin({ data: { outcome: "maybe" }, error: null }), "{}");
  assertEquals(res.status, 500);
});

Deno.test("only POST, with a body of a bounded size, reaches the database", async () => {
  const fake = fakeAdmin({ data: { outcome: "applied" }, error: null });
  assertEquals((await post(fake, null, { method: "GET" })).status, 405);
  assertEquals((await post(fake, "")).status, 400);
  assertEquals((await post(fake, "x".repeat(MAX_BODY_BYTES + 1))).status, 413);
  assertEquals(fake.calls.length, 0);
});

// #2563 — a retry of an event the home refused the first time: the
// duplicate answer says what the first delivery decided, so the sender books
// it refused, not delivered.
Deno.test("a duplicate carries the first outcome", async () => {
  const res = await post(
    fakeAdmin({ data: { outcome: "duplicate", first_outcome: "wrong_issuer" }, error: null }),
    "{}",
  );
  assertEquals(res.status, 200);
  assertEquals(res.body, { outcome: "duplicate", first_outcome: "wrong_issuer" });
});

Deno.test("a duplicate of a success carries its first outcome too", async () => {
  const res = await post(
    fakeAdmin({ data: { outcome: "duplicate", first_outcome: "applied" }, error: null }),
    "{}",
  );
  assertEquals(res.body, { outcome: "duplicate", first_outcome: "applied" });
});

Deno.test("only a duplicate carries a first outcome, and only a named one", async () => {
  const other = await post(
    fakeAdmin({ data: { outcome: "applied", first_outcome: "wrong_issuer" }, error: null }),
    "{}",
  );
  assertEquals(other.body, { outcome: "applied" });
  for (const first of [null, 7, ""]) {
    const res = await post(
      fakeAdmin({ data: { outcome: "duplicate", first_outcome: first }, error: null }),
      "{}",
    );
    assertEquals(res.body, { outcome: "duplicate" });
  }
});

// #4412 -- an uncaught error is the envelope: a code and the request id, never the error's own words.
Deno.test("#4412 federation-inbox: a thrown error answers the envelope and no internal message", async () => {
  const saved = console.error;
  console.error = () => {};
  try {
    const answer = await serve({
      admin: () => {
        throw new Error("service role key sb_secret_xyz is wrong");
      },
    })(
      new Request("https://x.test/functions/v1/federation-inbox", {
        method: "POST",
        body: "{}",
        headers: { "x-request-id": "r-fed" },
      }),
    );
    assertEquals(answer.status, 500);
    const text = await answer.text();
    assertEquals(JSON.parse(text), { error: "internal_error", request_id: "r-fed" });
    assertEquals(/secret|sb_|wrong/i.test(text), false);
  } finally {
    console.error = saved;
  }
});
