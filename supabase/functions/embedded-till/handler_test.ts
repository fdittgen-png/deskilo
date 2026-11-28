// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 -- the till board's routes: a claim and a status reach their database function with exactly the board's
// values; another method or action, a query string, a body over its ceiling or not JSON, a value of the wrong form,
// or a source past its budget is refused before the database; a database that fails or answers nothing readable is
// "uncertain", never a refusal the board would believe. The database's own rules are pgTAP 592's.
import { assertEquals } from "jsr:@std/assert@1";
import { budget, handle, MAX_BODY_BYTES, MAX_COMMAND_BYTES, MAX_SOURCES, sourceOf } from "./handler.ts";

const DEVICE = "11111111-1111-4111-8111-111111111111";
const HASH = "ab".repeat(32);
const REQUEST = "22222222-2222-4222-8222-222222222222";
type Args = Record<string, unknown>;

function db(answer: unknown = { ok: true, status: "pending_approval" }, error: { message: string } | null = null) {
  const calls: { fn: string; args: Args }[] = [];
  return {
    calls,
    deps: {
      rpc: (fn: string, args: Args) => {
        calls.push({ fn, args });
        return Promise.resolve({ data: answer, error });
      },
      allow: () => true,
    },
  };
}

const post = (body: unknown, url = "http://x/embedded-till") =>
  new Request(url, { method: "POST", body: typeof body === "string" ? body : JSON.stringify(body) });

const claim = {
  action: "enrollment.claim",
  code: "ABCD-EFGH-JKMN",
  device_id: DEVICE,
  secret_hash: HASH,
  firmware: "a7e83a3",
  protocol: "v1",
  claim_request_id: REQUEST,
};

Deno.test("a claim reaches the claim function with the board's values, and its answer comes back", async () => {
  const d = db();
  const res = await handle(post(claim), d.deps);
  assertEquals(await res.json(), { ok: true, status: "pending_approval" });
  assertEquals(d.calls, [{
    fn: "till_terminal_claim_v1",
    args: {
      p_code: "ABCD-EFGH-JKMN",
      p_device_id: DEVICE,
      p_secret_hash: HASH,
      p_firmware: "a7e83a3",
      p_protocol: "v1",
      p_claim_request_id: REQUEST,
    },
  }]);
});

Deno.test("a status reaches the status function, the database's refusal comes back as it is", async () => {
  const d = db({ ok: false, reason: "device_revoked" });
  const res = await handle(post({ action: "enrollment.status", device_id: DEVICE, secret: HASH }), d.deps);
  assertEquals([res.status, await res.json()], [200, { ok: false, reason: "device_revoked" }]);
  assertEquals(d.calls[0], { fn: "till_terminal_status_v1", args: { p_device_id: DEVICE, p_secret: HASH } });
});

Deno.test("what is not a board's request is refused before the database", async () => {
  const cases: [Request, number, string][] = [
    [new Request("http://x", { method: "GET" }), 405, "protocol_unsupported"],
    [post({ ...claim, action: "receipt.finalize" }), 400, "protocol_unsupported"],
    [post({ ...claim, action: undefined }), 400, "protocol_unsupported"],
    [post(claim, "http://x/embedded-till?code=ABCD"), 400, "protocol_unsupported"],
    [post("not json"), 400, "protocol_unsupported"],
    [post("[1,2]"), 400, "protocol_unsupported"],
    [post({ ...claim, protocol: "two" }), 400, "protocol_unsupported"],
    [post({ ...claim, device_id: "not-a-uuid" }), 400, "pair_proof_invalid"],
    [post({ ...claim, secret_hash: "AB".repeat(32) }), 400, "pair_proof_invalid"],
    [post({ ...claim, code: "x".repeat(40) }), 400, "pair_proof_invalid"],
    [post({ ...claim, firmware: "with space" }), 400, "pair_proof_invalid"],
    [post({ ...claim, claim_request_id: 7 }), 400, "pair_proof_invalid"],
    [post({ action: "enrollment.status", device_id: DEVICE, secret: "short" }), 400, "pair_proof_invalid"],
  ];
  for (const [req, status, reason] of cases) {
    const d = db();
    const res = await handle(req, d.deps);
    assertEquals([res.status, (await res.json()).reason, d.calls.length], [status, reason, 0], req.url);
  }
});

Deno.test("the largest body passes and one byte more is refused", async () => {
  const base = JSON.stringify({ ...claim, pad: "" });
  const exact = JSON.stringify({ ...claim, pad: "x".repeat(MAX_BODY_BYTES - base.length) });
  assertEquals(exact.length, MAX_BODY_BYTES);
  const d = db();
  assertEquals((await handle(post(exact), d.deps)).status, 200);
  const over = JSON.stringify({ ...claim, pad: "x".repeat(MAX_BODY_BYTES - base.length + 1) });
  const res = await handle(post(over), d.deps);
  assertEquals([res.status, (await res.json()).reason], [413, "payload_too_large"]);
});

Deno.test("invalid UTF-8 is no request", async () => {
  const d = db();
  const res = await handle(new Request("http://x", { method: "POST", body: new Uint8Array([0x7b, 0xff, 0x7d]) }), d.deps);
  assertEquals([res.status, d.calls.length], [400, 0]);
});

Deno.test("a source past its budget is refused for the rest of the minute", async () => {
  let t = 0;
  const allow = budget(2, () => t);
  assertEquals([allow("a"), allow("a"), allow("a"), allow("b")], [true, true, false, true]);
  t = 60_000;
  assertEquals(allow("a"), true);
  const d = db();
  const res = await handle(post(claim), { ...d.deps, allow: () => false });
  assertEquals([res.status, (await res.json()).reason, d.calls.length], [429, "rate_limited", 0]);
});

Deno.test("a database that fails or answers nothing readable is uncertain, not a refusal", async () => {
  for (const d of [db(null, { message: "connection reset" }), db("text"), db({ status: "paired" })]) {
    const res = await handle(post(claim), d.deps);
    assertEquals([res.status, await res.json()], [503, { ok: false, reason: "uncertain" }]);
  }
});

Deno.test("a delegated token is refused before anything", async () => {
  const d = db();
  const token = ["x", btoa(JSON.stringify({ client_id: "assistant" })), "y"].join(".");
  const res = await handle(
    new Request("http://x", { method: "POST", body: JSON.stringify(claim), headers: { Authorization: `Bearer ${token}` } }),
    d.deps,
  );
  assertEquals([res.status, d.calls.length], [403, 0]);
});

Deno.test("the budget counts the hop the proxy appended, not one the caller wrote first", () => {
  const req = new Request("http://x", { method: "POST", headers: { "x-forwarded-for": "6.6.6.6, 203.0.113.9" } });
  assertEquals(sourceOf(req), "203.0.113.9");
});

Deno.test("a flood of new sources never shuts out a new board", () => {
  let t = 0;
  const allow = budget(1, () => t);
  assertEquals([allow("a"), allow("a")], [true, false]);
  for (let i = 0; i < MAX_SOURCES; i++) allow(`s${i}`);
  assertEquals(allow("board"), true, "a new source is let in while every slot holds a live minute: the oldest goes");
  assertEquals(allow("board"), false, "and its own budget still counts");
  t = 60_000;
  assertEquals(allow("board"), true, "a new minute is a new budget");
});

Deno.test("a body that declares more than the ceiling is not read", async () => {
  const d = db();
  const res = await handle(
    new Request("http://x", { method: "POST", body: "{}", headers: { "content-length": String(MAX_COMMAND_BYTES + 1) } }),
    d.deps,
  );
  assertEquals([res.status, d.calls.length], [413, 0]);
});
