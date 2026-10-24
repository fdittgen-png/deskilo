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
import { handle, MAX_BODY_BYTES } from "./index.ts";

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
    ["bad_signature", 401],
    ["unknown_installation", 401],
    ["unknown_key", 401],
    ["bad_digest", 400],
    ["event_conflict", 409],
    ["revision_conflict", 409],
    ["snapshot_conflict", 409],
    ["wrong_target", 421],
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
