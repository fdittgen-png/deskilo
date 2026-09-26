// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1616 — the MCP endpoint through its real handler and the official SDK,
// with the network stubbed at Supabase's boundary: initialize, tools/list
// and tools/call over stateless Streamable HTTP; the list is the caller's
// own; two callers never share it; refusals for a missing or native
// token, a foreign origin, an oversized or malformed body, an unknown
// tool and a forbidden field; and the facade's status reaches the result
// truthfully (pending is not done).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { handle } from "./index.ts";

function jwt(claims: Record<string, unknown>): string {
  const b = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  return `${b({ alg: "HS256" })}.${b(claims)}.sig`;
}
const ALICE = jwt({ sub: "alice", role: "authenticated", client_id: "claude-test" });
const BOB = jwt({ sub: "bob", role: "authenticated", client_id: "claude-test" });
const NATIVE = jwt({ sub: "alice", role: "authenticated" });

const calls: { path: string; token: string; body: unknown }[] = [];
const operationsOf: Record<string, string[]> = {
  [ALICE]: ["create_reservation", "get_capabilities"],
  [BOB]: ["get_capabilities"],
};
let envelope: Record<string, unknown> = { schema_version: 1, status: "completed", data: {} };

Deno.env.set("SUPABASE_URL", "https://stub.supabase.test");
Deno.env.set("SUPABASE_ANON_KEY", "sb_publishable_stub");
Deno.env.set("DESKILO_INSTALLATION_ID", "0ea54888-a3d7-441f-a025-ee4576cf2fa9");
Deno.env.set("DESKILO_MCP_ALLOWED_ORIGINS", "https://app.deskilo.test");

globalThis.fetch = async (input: string | URL | Request, init?: RequestInit) => {
  const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
  const headers = new Headers(init?.headers ?? (input instanceof Request ? input.headers : undefined));
  const token = (headers.get("Authorization") ?? "").replace("Bearer ", "");
  const body = init?.body ? JSON.parse(String(init.body)) : null;
  calls.push({ path: url.pathname, token, body });
  if (url.pathname === "/auth/v1/user") {
    return Response.json({ id: token === ALICE ? "alice" : "bob", aud: "authenticated" });
  }
  if (url.pathname === "/rest/v1/rpc/mcp_my_operations") {
    return Response.json({ operations: operationsOf[token] ?? [], workspaces: [] });
  }
  if (url.pathname === "/rest/v1/rpc/mcp_execute_v1") return Response.json(envelope);
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
  assert(r.json.result.content[0].text.includes("Not completed yet"));
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
  assert(r.json.result.content[0].text.includes("not_eligible"));
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
