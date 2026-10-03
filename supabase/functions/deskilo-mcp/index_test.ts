// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1616 — the MCP endpoint through its real handler and the official SDK,
// with the network stubbed at Supabase's boundary: initialize, tools/list
// and tools/call over stateless Streamable HTTP; the list is the caller's
// own; two callers never share it; refusals for a missing or native
// token, a foreign origin, an oversized or malformed body, an unknown
// tool and a forbidden field; and the facade's status reaches the result
// truthfully (pending is not done). #1632: interleaved and retried calls
// keep the JSON-RPC id and the request UUID apart and associated, and a
// relabelled answer is refused.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { handle, projectData, LIMITS, REFUSAL_TEXT, summarize } from "./index.ts";

function jwt(claims: Record<string, unknown>): string {
  const b = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  return `${b({ alg: "HS256" })}.${b(claims)}.sig`;
}
const ALICE = jwt({ sub: "alice", role: "authenticated", client_id: "claude-test" });
const BOB = jwt({ sub: "bob", role: "authenticated", client_id: "claude-test" });
const NATIVE = jwt({ sub: "alice", role: "authenticated" });

const calls: { path: string; token: string; body: unknown; epoch: string | null }[] = [];
const operationsOf: Record<string, string[]> = {
  [ALICE]: ["create_reservation", "get_capabilities"],
  [BOB]: ["get_capabilities"],
};
let discoveredWorkspaces: unknown[] = [];
let envelope: Record<string, unknown> = { schema_version: 1, status: "completed", data: {} };
/** #1632 — a facade answer relabelled after the fact (a controlled fault). */
let mislabel: Record<string, unknown> = {};
/** #1632 — per-workspace answer delays, to release answers out of order. */
const delays: Record<string, number> = {};

Deno.env.set("SUPABASE_URL", "https://stub.supabase.test");
Deno.env.set("SUPABASE_ANON_KEY", "sb_publishable_stub");
Deno.env.set("DESKILO_INSTALLATION_ID", "0ea54888-a3d7-441f-a025-ee4576cf2fa9");
Deno.env.set("DESKILO_MCP_ALLOWED_ORIGINS", "https://app.deskilo.test");
Deno.env.set("DESKILO_MCP_EPOCH", "3");

globalThis.fetch = async (input: string | URL | Request, init?: RequestInit) => {
  const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
  const headers = new Headers(init?.headers ?? (input instanceof Request ? input.headers : undefined));
  const token = (headers.get("Authorization") ?? "").replace("Bearer ", "");
  const body = init?.body ? JSON.parse(String(init.body)) : null;
  calls.push({ path: url.pathname, token, body, epoch: headers.get("x-deskilo-mcp-epoch") });
  if (url.pathname === "/auth/v1/user") {
    return Response.json({ id: token === ALICE ? "alice" : "bob", aud: "authenticated" });
  }
  if (url.pathname === "/rest/v1/rpc/mcp_my_operations") {
    return Response.json({ operations: operationsOf[token] ?? [], workspaces: discoveredWorkspaces });
  }
  if (url.pathname === "/rest/v1/rpc/mcp_execute_v1") {
    // The facade names what it answers (mcp_envelope): echo the call.
    const sent = body as Record<string, unknown>;
    const delay = delays[String(sent.p_workspace_id)] ?? 0;
    if (delay) await new Promise((r) => setTimeout(r, delay));
    return Response.json({
      operation: sent.p_operation,
      ...(sent.p_workspace_id ? { workspace_id: sent.p_workspace_id } : {}),
      ...(sent.p_request_id ? { request_id: sent.p_request_id } : {}),
      ...envelope,
      ...mislabel,
    });
  }
  return new Response("not stubbed", { status: 500 });
};

let nextId = 1;
async function rpc(token: string | null, method: string, params: unknown = {}, extra: Record<string, string> = {}) {
  const res = await handle(new Request("https://stub.supabase.test/functions/v1/deskilo-mcp", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      accept: "application/json, text/event-stream",
      "mcp-protocol-version": "2025-06-18",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...extra,
    },
    body: JSON.stringify({ jsonrpc: "2.0", id: nextId++, method, params }),
  }));
  const text = await res.text();
  return { status: res.status, headers: res.headers, json: text ? JSON.parse(text) : null };
}

const init = { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" } };

Deno.test("initialize answers the protocol and advertises tools only", async () => {
  const r = await rpc(ALICE, "initialize", init);
  assertEquals(r.status, 200);
  assertEquals(r.json.result.protocolVersion, "2025-06-18");
  assert(r.json.result.capabilities.tools);
  assertEquals(r.json.result.capabilities.resources, undefined);
  assertEquals(r.json.result.capabilities.prompts, undefined);
});

Deno.test("tools/list is the caller's own, and two callers never share it", async () => {
  const alice = await rpc(ALICE, "tools/list");
  const bob = await rpc(BOB, "tools/list");
  const names = (r: typeof alice) => r.json.result.tools.map((t: { name: string }) => t.name).sort();
  assertEquals(names(alice), ["deskilo_create_reservation", "deskilo_get_capabilities", "deskilo_list_workspaces"]);
  assertEquals(names(bob), ["deskilo_get_capabilities", "deskilo_list_workspaces"]);
  const listCalls = calls.filter((c) => c.path === "/rest/v1/rpc/mcp_my_operations");
  assert(listCalls.some((c) => c.token === ALICE) && listCalls.some((c) => c.token === BOB));
  const create = alice.json.result.tools.find((t: { name: string }) => t.name === "deskilo_create_reservation");
  assertEquals(create.inputSchema.additionalProperties, false);
});

Deno.test("tools/call goes through the facade with the caller's own token", async () => {
  envelope = { schema_version: 1, status: "pending_validation", data: { event_id: "e1" } };
  const r = await rpc(ALICE, "tools/call", {
    name: "deskilo_request_reservation_deletion",
    arguments: { request_id: "6b1d3f0e-0000-4000-8000-000000000001", workspace_id: "6b1d3f0e-0000-4000-8000-000000000002", reservation_id: "6b1d3f0e-0000-4000-8000-000000000003" },
  });
  assertEquals(r.status, 200);
  assertEquals(r.json.result.isError, false);
  assertEquals(r.json.result.structuredContent.status, "pending_validation");
  assert(r.json.result.content[0].text.includes("NOT completed yet"));
  const call = calls.findLast((c) => c.path === "/rest/v1/rpc/mcp_execute_v1")!;
  assertEquals(call.token, ALICE);
  const body = call.body as Record<string, unknown>;
  assertEquals(body.p_operation, "request_reservation_deletion");
  assertEquals(body.p_request_id, "6b1d3f0e-0000-4000-8000-000000000001");
  assertEquals((body.p_arguments as Record<string, unknown>).workspace_id, undefined);
});

Deno.test("a refusal from the facade is an error result, never 'done'", async () => {
  envelope = { schema_version: 1, status: "denied", error: { code: "not_eligible" } };
  const r = await rpc(ALICE, "tools/call", { name: "deskilo_get_capabilities", arguments: { workspace_id: "6b1d3f0e-0000-4000-8000-000000000002" } });
  assertEquals(r.json.result.isError, true);
  assertEquals(r.json.result.structuredContent.error.code, "not_eligible");
  // #2145 — the person's next step in plain words, not the code.
  assert(r.json.result.content[0].text.includes("Settings → Assistants"));
  assert(!r.json.result.content[0].text.includes("not_eligible"));
});

Deno.test("unknown tools and forbidden fields never reach the database", async () => {
  const before = calls.filter((c) => c.path === "/rest/v1/rpc/mcp_execute_v1").length;
  const unknown = await rpc(ALICE, "tools/call", { name: "deskilo_drop_everything", arguments: {} });
  assertEquals(unknown.json.result.isError, true);
  const forbidden = await rpc(ALICE, "tools/call", {
    name: "deskilo_get_capabilities",
    arguments: { workspace_id: "6b1d3f0e-0000-4000-8000-000000000002", user_id: "someone-else" },
  });
  assertEquals(forbidden.json.result.isError, true);
  assertEquals(calls.filter((c) => c.path === "/rest/v1/rpc/mcp_execute_v1").length, before);
});

Deno.test("no token, a native token, a foreign origin: refused before any work", async () => {
  const none = await rpc(null, "tools/list");
  assertEquals(none.status, 401);
  assert((none.headers.get("WWW-Authenticate") ?? "").includes("oauth-protected-resource"));
  assertEquals((await rpc(NATIVE, "tools/list")).status, 401);
  assertEquals((await rpc(ALICE, "tools/list", {}, { Origin: "https://evil.test" })).status, 403);
  const allowed = await rpc(ALICE, "tools/list", {}, { Origin: "https://app.deskilo.test" });
  assertEquals(allowed.headers.get("Access-Control-Allow-Origin"), "https://app.deskilo.test");
});

Deno.test("oversized, malformed and wrongly typed bodies are bounded answers", async () => {
  const big = await handle(new Request("https://stub.supabase.test/functions/v1/deskilo-mcp", {
    method: "POST",
    headers: { "content-type": "application/json", Authorization: `Bearer ${ALICE}` },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list", params: { pad: "x".repeat(70 * 1024) } }),
  }));
  assertEquals(big.status, 413);
  const bad = await handle(new Request("https://stub.supabase.test/functions/v1/deskilo-mcp", {
    method: "POST", headers: { "content-type": "application/json", Authorization: `Bearer ${ALICE}` }, body: "{nope",
  }));
  assertEquals(bad.status, 400);
  const text = await handle(new Request("https://stub.supabase.test/functions/v1/deskilo-mcp", {
    method: "POST", headers: { "content-type": "text/plain", Authorization: `Bearer ${ALICE}` }, body: "{}",
  }));
  assertEquals(text.status, 415);
  const get = await handle(new Request("https://stub.supabase.test/functions/v1/deskilo-mcp", { method: "GET" }));
  assertEquals(get.status, 405);
});

Deno.test("the protected-resource metadata is public and names the configured issuer", async () => {
  const r = await handle(new Request("https://attacker.test/functions/v1/deskilo-mcp/.well-known/oauth-protected-resource"));
  assertEquals(r.status, 200);
  const meta = await r.json();
  assertEquals(meta.authorization_servers, ["https://stub.supabase.test/auth/v1"]);
  assert(!String(meta.resource).includes("attacker"));
});

Deno.test("without a configured installation it serves nothing", async () => {
  Deno.env.delete("DESKILO_INSTALLATION_ID");
  try {
    assertEquals((await rpc(ALICE, "tools/list")).status, 503);
  } finally {
    Deno.env.set("DESKILO_INSTALLATION_ID", "0ea54888-a3d7-441f-a025-ee4576cf2fa9");
  }
});

Deno.test("#1631 without a configured epoch, or with a malformed one, it serves nothing", async () => {
  for (const value of [null, "0", "three", "-1"]) {
    if (value === null) Deno.env.delete("DESKILO_MCP_EPOCH");
    else Deno.env.set("DESKILO_MCP_EPOCH", value);
    try {
      const before = calls.length;
      assertEquals((await rpc(ALICE, "tools/list")).status, 503);
      assertEquals(calls.length, before, "nothing reaches Auth or the database");
    } finally {
      Deno.env.set("DESKILO_MCP_EPOCH", "3");
    }
  }
});

Deno.test("#1631 every database request carries the epoch this endpoint was deployed for", async () => {
  const before = calls.length;
  await rpc(ALICE, "tools/list");
  await rpc(ALICE, "tools/call", { name: "deskilo_get_capabilities", arguments: { workspace_id: "6b1d3f0e-0000-4000-8000-000000000002" } });
  const database = calls.slice(before).filter((c) => c.path.startsWith("/rest/v1/"));
  assert(database.length >= 2);
  for (const c of database) assertEquals(c.epoch, "3");
});

Deno.test("#1644 the adapter keeps only operational fields, however deep", () => {
  const out = projectData("get_availability", {
    window: { starts_at: "a", ends_at: "b", organiser: "alice@example.org" },
    items: [{ seat_id: "s1", free: true, note: "private" }],
    next_cursor: null,
    debug: "select * from members",
  }) as Record<string, unknown>;
  assertEquals(out, {
    window: { starts_at: "a", ends_at: "b" },
    items: [{ seat_id: "s1", free: true }],
    next_cursor: null,
  });
  assert(!JSON.stringify(out).includes("alice"));
});

Deno.test("#1645 an optional field the database disclosed passes; elsewhere it is still dropped", () => {
  // The database sent the seat's name only because all four layers agreed.
  const disclosed = projectData("get_availability", {
    items: [{ seat_id: "s1", name: "Desk 1", free: true, note: "private" }],
  }) as Record<string, unknown>;
  assertEquals(disclosed, { items: [{ seat_id: "s1", name: "Desk 1", free: true }] });
  // No operation but those the contract names may carry it.
  const elsewhere = projectData("list_my_reservations", {
    items: [{ reservation_id: "r1", name: "Alice" }],
  }) as Record<string, unknown>;
  assertEquals(elsewhere, { items: [{ reservation_id: "r1" }] });
});

Deno.test("browser clients can read the authentication challenge", async () => {
  const r = await rpc(null, "tools/list", {}, { Origin: "https://app.deskilo.test" });
  assertEquals(r.status, 401);
  assert((r.headers.get("Access-Control-Expose-Headers") ?? "").toLowerCase().includes("www-authenticate"));
});

Deno.test("text-only clients receive the same projected data", async () => {
  envelope = { status: "completed", data: { window: { starts_at: "2030-01-01", private_note: "hidden" } } };
  const r = await rpc(ALICE, "tools/call", { name: "deskilo_get_availability", arguments: {} });
  const json = r.json.result.content.find((c: {text?: string}) => c.text?.startsWith("{"));
  assert(json);
  assertEquals(JSON.parse(json.text), r.json.result.structuredContent);
  assert(!json.text.includes("hidden"));
});

Deno.test("output limits count UTF-8 bytes, including workspace discovery", async () => {
  const large = "界".repeat(100_000);
  envelope = { status: "completed", data: { window: { starts_at: large } } };
  const r = await rpc(ALICE, "tools/call", { name: "deskilo_get_availability", arguments: {} });
  assertEquals(r.json.result.isError, true);
  assertEquals(r.json.result.structuredContent, undefined);
  discoveredWorkspaces = [{ workspace_id: "w", name: large }];
  try {
    const listing = await rpc(ALICE, "tools/call", { name: "deskilo_list_workspaces", arguments: {} });
    assertEquals(listing.json.result.isError, true);
    assertEquals(listing.json.result.structuredContent, undefined);
  } finally { discoveredWorkspaces = []; }
});

Deno.test("workspace discovery respects the advertised limit", async () => {
  discoveredWorkspaces = [{ workspace_id: "one" }, { workspace_id: "two" }];
  try {
    const r = await rpc(ALICE, "tools/call", { name: "deskilo_list_workspaces", arguments: {limit: 1} });
    assertEquals(r.json.result.structuredContent.workspaces, [{workspace_id: "one"}]);
    assertEquals(r.json.result.structuredContent.has_more, true);
  } finally { discoveredWorkspaces = []; }
});

Deno.test("oversized streamed requests cancel before reading the whole stream", async () => {
  let cancelled = false;
  const body = new ReadableStream<Uint8Array>({
    start(controller) { controller.enqueue(new Uint8Array(LIMITS.inputBytes + 1)); },
    pull(controller) { controller.enqueue(new Uint8Array(1)); controller.close(); },
    cancel() { cancelled = true; },
  });
  const r = await handle(new Request("https://stub.supabase.test/functions/v1/deskilo-mcp", {
    method: "POST", headers: {"content-type": "application/json", Authorization: `Bearer ${ALICE}`}, body,
  }));
  assertEquals(r.status, 413);
  assert(cancelled);
});

Deno.test("authentication is inside the request deadline and cannot dispatch afterward", async () => {
  const previousFetch = globalThis.fetch, previousDeadline = LIMITS.deadlineMs;
  LIMITS.deadlineMs = 10;
  let authenticated = false;
  globalThis.fetch = (_input, init) => {
    assert(init?.signal, "auth fetch must carry the request deadline");
    authenticated = true;
    return new Promise((_resolve, reject) => init.signal!.addEventListener("abort", () => reject(new DOMException("Aborted", "AbortError")), { once: true }));
  };
  const before = calls.length;
  try {
    const r = await rpc(ALICE, "tools/list");
    assert(authenticated);
    assertEquals(r.status, 504);
    assertEquals(calls.length, before);
  } finally { globalThis.fetch = previousFetch; LIMITS.deadlineMs = previousDeadline; }
});

Deno.test("stalled request bodies expire before authentication", async () => {
  const previousDeadline = LIMITS.deadlineMs;
  LIMITS.deadlineMs = 10;
  let cancelled = false;
  const before = calls.length;
  const body = new ReadableStream<Uint8Array>({ cancel() { cancelled = true; } });
  try {
    const r = await handle(new Request("https://stub.supabase.test/functions/v1/deskilo-mcp", {
      method: "POST", headers: { "content-type": "application/json", Authorization: `Bearer ${ALICE}` }, body,
    }));
    assertEquals(r.status, 504);
    assert(cancelled);
    assertEquals(calls.length, before);
  } finally { LIMITS.deadlineMs = previousDeadline; }
});

// ── #1632 — provenance: the request UUID is not the JSON-RPC id ─────────

const WS_A = "6b1d3f0e-0000-4000-8000-00000000000a";
const WS_B = "6b1d3f0e-0000-4000-8000-00000000000b";

async function call(jsonrpcId: number, args: Record<string, unknown>, name = "deskilo_create_reservation") {
  const res = await handle(new Request("https://stub.supabase.test/functions/v1/deskilo-mcp", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      accept: "application/json, text/event-stream",
      "mcp-protocol-version": "2025-06-18",
      Authorization: `Bearer ${ALICE}`,
    },
    body: JSON.stringify({ jsonrpc: "2.0", id: jsonrpcId, method: "tools/call", params: { name, arguments: args } }),
  }));
  return await res.json();
}

const booking = (ws: string, requestId: string) => ({
  request_id: requestId, workspace_id: ws, seat_id: "6b1d3f0e-0000-4000-8000-000000000003",
  starts_at: "2030-01-01T08:00:00Z", ends_at: "2030-01-01T12:00:00Z",
});

Deno.test("#1632 interleaved A and B calls keep both ids apart and associated, answered out of order", async () => {
  envelope = { schema_version: 1, status: "completed", data: {} };
  delays[WS_A] = 40; // A's answer arrives after B's
  const before = calls.length;
  try {
    const [a, b] = await Promise.all([
      call(41, booking(WS_A, "6b1d3f0e-0000-4000-8000-0000000000a1")),
      call(42, booking(WS_B, "6b1d3f0e-0000-4000-8000-0000000000b1")),
    ]);
    assertEquals(a.id, 41);
    assertEquals(b.id, 42);
    assertEquals(a.result.structuredContent.request_id, "6b1d3f0e-0000-4000-8000-0000000000a1");
    assertEquals(a.result.structuredContent.workspace_id, WS_A);
    assertEquals(b.result.structuredContent.request_id, "6b1d3f0e-0000-4000-8000-0000000000b1");
    assertEquals(b.result.structuredContent.workspace_id, WS_B);
    const sent = calls.slice(before).filter((c) => c.path === "/rest/v1/rpc/mcp_execute_v1")
      .map((c) => c.body as Record<string, unknown>);
    assertEquals(sent.map((s) => s.p_request_id).sort(),
      ["6b1d3f0e-0000-4000-8000-0000000000a1", "6b1d3f0e-0000-4000-8000-0000000000b1"],
      "the database receives the request UUIDs, never the JSON-RPC ids");
    for (const s of sent) assert(![41, 42, "41", "42"].includes(s.p_request_id as never));
  } finally { delete delays[WS_A]; }
});

Deno.test("#1632 the same request UUID retried under a new JSON-RPC id is the same request", async () => {
  envelope = { schema_version: 1, status: "completed", data: {} };
  const before = calls.length;
  const first = await call(51, booking(WS_A, "6b1d3f0e-0000-4000-8000-0000000000a2"));
  const retry = await call(52, booking(WS_A, "6b1d3f0e-0000-4000-8000-0000000000a2"));
  assertEquals([first.id, retry.id], [51, 52]);
  const sent = calls.slice(before).filter((c) => c.path === "/rest/v1/rpc/mcp_execute_v1")
    .map((c) => (c.body as Record<string, unknown>).p_request_id);
  assertEquals(sent, ["6b1d3f0e-0000-4000-8000-0000000000a2", "6b1d3f0e-0000-4000-8000-0000000000a2"]);
});

for (const [what, wrong] of [
  ["workspace", { workspace_id: WS_B }],
  ["request id", { request_id: "6b1d3f0e-0000-4000-8000-0000000000ff" }],
  ["operation", { operation: "check_in" }],
] as const) {
  Deno.test(`#1632 an answer labelled with another ${what} is refused, never delivered`, async () => {
    envelope = { schema_version: 1, status: "completed", data: { reservation_id: "r-of-someone-else" } };
    mislabel = wrong;
    try {
      const r = await call(61, booking(WS_A, "6b1d3f0e-0000-4000-8000-0000000000a3"));
      assertEquals(r.id, 61);
      assertEquals(r.result.isError, true);
      assertEquals(r.result.structuredContent, undefined);
      assert(!JSON.stringify(r).includes("r-of-someone-else"));
    } finally { mislabel = {}; }
  });
}

// #2145 — what a model reads: the contract's own words, the server's
// instructions, and refusals that say what to do next.

Deno.test("#2145 tools/list serves exactly the generated tool definitions", async () => {
  const generated = JSON.parse(await Deno.readTextFile(new URL("../../../contracts/mcp/generated/tools.json", import.meta.url)));
  const byName = new Map(generated.tools.map((t: { name: string }) => [t.name, t]));
  const r = await rpc(ALICE, "tools/list");
  for (const tool of r.json.result.tools) {
    assertEquals(tool, byName.get(tool.name), tool.name);
    assert(tool.title && !tool.description.startsWith("Deskilo:"), tool.name);
    assertEquals(tool.annotations.openWorldHint, false);
    assert(tool.outputSchema?.type === "object", tool.name);
  }
  const create = r.json.result.tools.find((t: { name: string }) => t.name === "deskilo_create_reservation");
  assertEquals(create.annotations.readOnlyHint, false);
  assertEquals(create.annotations.destructiveHint, false);
  assertEquals(create.annotations.idempotentHint, true);
  assert(create.inputSchema.properties.request_id.description.includes("SAME request_id"));
  assert(create.inputSchema.properties.starts_at.examples[0].endsWith("+02:00"));
});

Deno.test("#2145 initialize carries the instructions that chain the tools", async () => {
  const r = await rpc(ALICE, "initialize", init);
  const text: string = r.json.result.instructions;
  for (const needle of ["deskilo_list_workspaces", "request_id", "requires_confirmation", "pending_validation", "minor units", "offset"]) {
    assert(text.includes(needle), needle);
  }
});

Deno.test("#2145 a rate limit keeps its wait, and says it", async () => {
  envelope = { schema_version: 1, status: "rate_limited", error: { code: "rate_limited" }, data: { retry_after: 42, secret: "x" } };
  const r = await rpc(ALICE, "tools/call", { name: "deskilo_get_capabilities", arguments: { workspace_id: "6b1d3f0e-0000-4000-8000-000000000002" } });
  assertEquals(r.json.result.isError, true);
  assertEquals(r.json.result.structuredContent.data, { retry_after: 42 });
  assert(r.json.result.content[0].text.includes("Wait 42 seconds"));
});

Deno.test("#2145 a confirmation says until when, where, and to retry with the same request id", () => {
  const envelope = { status: "requires_confirmation", data: { confirmation_id: "00000000-0000-4000-8000-0000000000c1", expires_at: "2026-10-03T12:05:00Z" } };
  Deno.env.delete("DESKILO_APP_URL");
  const plain = summarize(envelope);
  assert(plain.startsWith("Nothing happened yet"));
  assert(plain.includes("before 2026-10-03T12:05:00Z"));
  assert(plain.includes("same request_id"));
  assert(!plain.includes("http"));
  Deno.env.set("DESKILO_APP_URL", "https://app.deskilo.test/");
  try {
    assert(summarize(envelope).includes("https://app.deskilo.test/#/mcp/confirm/00000000-0000-4000-8000-0000000000c1"));
    // An id that is not a UUID never becomes a link.
    assert(!summarize({ ...envelope, data: { confirmation_id: "../x" } }).includes("http"));
  } finally { Deno.env.delete("DESKILO_APP_URL"); }
});

Deno.test("#2145 a business refusal is quoted; pending is never 'done'", () => {
  assertEquals(
    summarize({ status: "conflict", error: { code: "refused" }, data: { reason: "outside the opening hours" } }),
    "Not done: outside the opening hours. Tell the person; the same rules apply in the DesKilo app.",
  );
  assert(!summarize({ status: "pending_validation" }).startsWith("Done"));
  assert(summarize({ status: "denied", error: { code: "something_new" } }).includes("something_new"));
});

Deno.test("#2145 every refusal code the facade can answer has plain words", async () => {
  const dir = new URL("../../migrations/", import.meta.url);
  const codes = new Set<string>();
  for await (const f of Deno.readDir(dir)) {
    if (!f.name.endsWith(".sql")) continue;
    const sql = await Deno.readTextFile(new URL(f.name, dir));
    if (!sql.includes("mcp_envelope")) continue;
    for (const m of sql.matchAll(/mcp_envelope\([^;]*?'(?:denied|validation_error|not_found|conflict)',\s*null,\s*'([a-z_]+)'/g)) codes.add(m[1]);
    for (const m of sql.matchAll(/'refused',\s*'[a-z_]+',\s*'code',\s*'([a-z_]+)'/g)) codes.add(m[1]);
    for (const m of sql.matchAll(/v_code := '([a-z_]+)'/g)) codes.add(m[1]);
  }
  assert(codes.has("not_eligible") && codes.has("not_exposed"), "the scan finds the facade's codes");
  codes.delete("refused"); // quoted from the business rule itself
  for (const code of codes) assert(REFUSAL_TEXT[code], `no plain words for ${code}`);
});
