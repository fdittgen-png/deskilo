// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 (slice 2) -- the cashier and the board's commands. A board asks for a cashier with its lease token's sha256; a
// cashier's verified token is sealed (AES-GCM, bound to the board, the cashier and their sign-in) and handed to the
// grant as the cashier, never in clear; without the function's key nothing is issued. A command is one of three, its
// arguments checked, the workspace and till taken from the lease, the cashier's token opened only for its binding, the
// call made as the cashier with every digit kept both ways; a refusal keeps its code, and a lost or unreadable answer
// is uncertain. The database's own rules are pgTAP 603's.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { handle, type RestCall, type Verified } from "./handler.ts";

const DEVICE = "11111111-1111-4111-8111-111111111111";
const TERMINAL = "33333333-3333-4333-8333-333333333333";
const WS = "44444444-4444-4444-8444-444444444444";
const TILL = "55555555-5555-4555-8555-555555555555";
const USER = "66666666-6666-4666-8666-666666666666";
const SESSION = "77777777-7777-4777-8777-777777777777";
const REQUEST = "22222222-2222-4222-8222-222222222222";
const SECRET = "ab".repeat(32);
const TOKEN = "cd".repeat(32);
const BEARER = "header.payload.signature";
type Args = Record<string, unknown>;

const key = await crypto.subtle.importKey("raw", new Uint8Array(32).fill(7), "AES-GCM", false, ["encrypt", "decrypt"]);
const otherKey = await crypto.subtle.importKey("raw", new Uint8Array(32).fill(9), "AES-GCM", false, ["encrypt", "decrypt"]);
const hex = (b: Uint8Array) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
const unhex = (h: string) => Uint8Array.from(h.match(/../g)!.map((x) => parseInt(x, 16)));
const b64 = (b: Uint8Array) => btoa(String.fromCharCode(...b));
const sha = async (t: string) => hex(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(t))));
const bind = (t: string, u: string, s: string) => new TextEncoder().encode(`deskilo-till-lease:v1|${t}|${u}|${s}`);

async function sealed(k: CryptoKey, bearer: string, t = TERMINAL, u = USER, s = SESSION) {
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const c = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce, additionalData: bind(t, u, s) }, k, new TextEncoder().encode(bearer)));
  return { token_ciphertext: b64(c), token_nonce: b64(nonce) };
}

async function lease(over: Args = {}) {
  return {
    ok: true, lease_id: "l", workspace_id: WS, terminal_id: TERMINAL, till_id: TILL, member_id: "m", user_id: USER,
    auth_session_id: SESSION, expires_at: "2026-12-01T00:00:00Z", ...(await sealed(key, BEARER)), ...over,
  };
}

function deps(answer: unknown, rest: { status: number; text: string } | Error = { status: 200, text: '{"ok":true}' }, k: CryptoKey | null = key) {
  const rpcCalls: { fn: string; args: Args }[] = [];
  const restCalls: { fn: string; body: string; bearer: string }[] = [];
  const call: RestCall = (fn, body, bearer) => {
    restCalls.push({ fn, body, bearer });
    if (rest instanceof Error) return Promise.reject(rest);
    return Promise.resolve({ status: rest.status, bytes: new TextEncoder().encode(rest.text) });
  };
  const verified: Verified = { userId: USER, sessionId: SESSION, expiresAt: new Date("2026-12-01T00:00:00Z") };
  return {
    rpcCalls,
    restCalls,
    deps: {
      rpc: (fn: string, args: Args) => {
        rpcCalls.push({ fn, args });
        return Promise.resolve({ data: answer, error: null });
      },
      allow: () => true,
      verify: (b: string) => Promise.resolve(b === BEARER ? verified : null),
      tokenKey: k,
      rest: call,
    },
  };
}

const post = (body: unknown, bearer?: string) =>
  new Request("http://x/embedded-till", {
    method: "POST",
    body: typeof body === "string" ? body : JSON.stringify(body),
    headers: bearer ? { authorization: `Bearer ${bearer}` } : {},
  });

const command = (op: string, args: unknown = {}) =>
  JSON.stringify({ action: "command", device_id: DEVICE, secret: SECRET, lease_token: TOKEN, op, args });

Deno.test("the board asks for a cashier with its lease token's sha256, nothing else", async () => {
  const d = deps({ ok: true, request_expires_at: "x" });
  const res = await handle(post({ action: "operator.request", device_id: DEVICE, secret: SECRET, lease_hash: "ef".repeat(32) }), d.deps);
  assertEquals(await res.json(), { ok: true, request_expires_at: "x" });
  assertEquals(d.rpcCalls, [{ fn: "till_terminal_lease_request_v1", args: { p_device_id: DEVICE, p_secret: SECRET, p_lease_hash: "ef".repeat(32) } }]);
});

Deno.test("a cashier authorizes the board as themselves: their token sealed for the board and their sign-in", async () => {
  const d = deps(null, { status: 200, text: `{"lease_id":"l","member_id":"m","expires_at":"x"}` });
  const res = await handle(post({ action: "operator.authorize", terminal_id: TERMINAL }, BEARER), d.deps);
  assertEquals((await res.json()).ok, true);
  assertEquals(d.rpcCalls.length, 0, "the grant is made as the cashier, never as the service role");
  const [{ fn, body, bearer }] = d.restCalls;
  assertEquals([fn, bearer], ["till_terminal_lease_grant_v1", BEARER]);
  assert(!body.includes(BEARER), "the token never travels in clear to the database");
  const sent = JSON.parse(body);
  const nonce = unhex(sent.p_token_nonce.slice(2)), c = unhex(sent.p_token_ciphertext.slice(2));
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: nonce, additionalData: bind(TERMINAL, USER, SESSION) }, key, c);
  assertEquals(new TextDecoder().decode(plain), BEARER);
  assertEquals(sent.p_token_expires_at, "2026-12-01T00:00:00.000Z");
});

Deno.test("no key, no verified bearer, no lease", async () => {
  let res = await handle(post({ action: "operator.authorize", terminal_id: TERMINAL }, BEARER), deps(null, undefined, null).deps);
  assertEquals([res.status, (await res.json()).reason], [503, "terminal_not_configured"]);
  res = await handle(post({ action: "operator.authorize", terminal_id: TERMINAL }, "forged"), deps(null).deps);
  assertEquals([res.status, (await res.json()).reason], [401, "operator_revoked"]);
  res = await handle(post({ action: "operator.authorize", terminal_id: TERMINAL }), deps(null).deps);
  assertEquals([res.status, (await res.json()).reason], [401, "operator_revoked"]);
});

Deno.test("a draft goes to the till as the cashier, its workspace and till the lease's, every digit kept", async () => {
  const answer = '{"receipt_id":"r","revision":1,"total_minor":9007199254740993,"vat":20.0}';
  const d = deps(await lease(), { status: 200, text: answer });
  // the board's own bytes: a JavaScript number would already have rounded 2^53 + 1
  const raw = command("draft", { request_id: REQUEST, receipt_id: null, expected_revision: 0, lines: "LINES" })
    .replace('"LINES"', '[{"item_id":"i","quantity":"2","unit_price_minor":9007199254740993}]');
  const res = await handle(post(raw), d.deps);
  assertEquals(await res.text(), `{"ok":true,"result":${answer}}`, "the answer comes back byte for byte");
  assertEquals(d.rpcCalls[0], { fn: "till_terminal_lease_resolve_v1", args: { p_device_id: DEVICE, p_secret: SECRET, p_lease_hash: await sha(TOKEN) } });
  const [{ fn, body, bearer }] = d.restCalls;
  assertEquals([fn, bearer], ["counter_receipt_draft_v1", BEARER]);
  assertEquals(body,
    `{"p_workspace_id":"${WS}","p_request_id":"${REQUEST}","p_receipt_id":null,"p_expected_revision":0,` +
      `"p_body":{"lines":[{"item_id":"i","quantity":"2","unit_price_minor":9007199254740993}],"till_id":"${TILL}"}}`);
});

Deno.test("the board names no workspace, no till and no function: anything else is no command", async () => {
  for (
    const bad of [
      command("refund"),
      command("draft", { request_id: REQUEST, lines: [], workspace_id: WS }),
      command("draft", { request_id: REQUEST, lines: [], till_id: TILL }),
      command("draft", { request_id: "not-a-uuid", lines: [] }),
      command("draft", { request_id: REQUEST, lines: {} }),
      command("finalize", { request_id: REQUEST, expected_revision: -1, tenders: [] }),
      command("finalize", { request_id: REQUEST, expected_revision: 9223372036854775808n.toString(), tenders: [] }),
    ]
  ) {
    const d = deps(await lease());
    const res = await handle(post(bad), d.deps);
    assertEquals([res.status, (await res.json()).reason, d.rpcCalls.length], [400, "protocol_unsupported", 0], bad);
  }
});

Deno.test("the lease's refusal comes back, and a token sealed for another board or by another key opens nothing", async () => {
  let d = deps({ ok: false, reason: "operator_expired" });
  assertEquals(await (await handle(post(command("readiness")), d.deps)).json(), { ok: false, reason: "operator_expired" });
  assertEquals(d.restCalls.length, 0);
  for (const over of [await sealed(key, BEARER, "99999999-9999-4999-8999-999999999999"), await sealed(otherKey, BEARER)]) {
    d = deps(await lease(over));
    assertEquals((await (await handle(post(command("readiness")), d.deps)).json()).reason, "operator_revoked");
    assertEquals(d.restCalls.length, 0);
  }
});

Deno.test("a refusal keeps its code; a lost, failed or unreadable financial answer is uncertain", async () => {
  let d = deps(await lease(), { status: 400, text: '{"code":"DKL02","details":"{\\"reason\\": \\"item\\"}","message":"x"}' });
  assertEquals(await (await handle(post(command("draft", { request_id: REQUEST, lines: [] })), d.deps)).json(),
    { ok: false, reason: "refused", code: "DKL02", detail: '{"reason": "item"}' });
  for (const rest of [new Error("timeout"), { status: 503, text: "" }, { status: 200, text: "{not json" }, { status: 400, text: '{"code":"XX000"}' }]) {
    d = deps(await lease(), rest);
    const res = await handle(post(command("finalize", { request_id: REQUEST, receipt_id: REQUEST, expected_revision: 2, tenders: [] })), d.deps);
    assertEquals((await res.json()).reason, "uncertain", JSON.stringify(rest));
  }
  d = deps(await lease(), { status: 401, text: '{"code":"PGRST301"}' });
  assertEquals((await (await handle(post(command("readiness")), d.deps)).json()).reason, "operator_expired");
});

Deno.test("a command past its ceiling is refused before anything", async () => {
  const d = deps(await lease());
  const res = await handle(post(command("draft", { request_id: REQUEST, lines: ["x".repeat(17000)] })), d.deps);
  assertEquals([res.status, d.rpcCalls.length], [413, 0]);
});
