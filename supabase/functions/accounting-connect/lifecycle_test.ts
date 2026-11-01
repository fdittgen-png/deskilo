// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The end of a connection: revoking it here and at the target (RFC 7009),
// and the check that a token reaches the company the manager named. The
// database and the target are played; no request leaves the test.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { type Deps, handle } from "./index.ts";

const CONN = "33333333-3333-4333-8333-333333333333";
const SECRET = "RT-very-secret";

type Call = { as: string; fn: string; args: Record<string, unknown> };

function world(opts: {
  target?: string;
  authKind?: string;
  allowed?: boolean;
  tenant?: string;
  secrets?: Record<string, string>;
  vendor?: (url: URL, init: RequestInit) => Response;
  revokeFails?: boolean;
} = {}) {
  const target = opts.target ?? "xero_gb";
  const calls: Call[] = [];
  const seen: { url: string; init: RequestInit }[] = [];
  const answer = (as: string) => ({
    rpc: (fn: string, args: Record<string, unknown>) => {
      calls.push({ as, fn, args });
      if (fn === "accounting_connection_manageable_v1") {
        return Promise.resolve(opts.allowed === false
          ? { data: null, error: { code: "42501" } }
          : { data: { id: CONN, workspace_id: "w", target_id: target, auth_kind: opts.authKind ?? "oauth2" }, error: null });
      }
      if (fn === "accounting_credentials_resolved") {
        return Promise.resolve({
          data: {
            id: CONN,
            workspace_id: "w",
            issuer_site_id: "s",
            target_id: target,
            auth_kind: opts.authKind ?? "oauth2",
            status: "connected",
            revoked: false,
            remote_tenant_id: opts.tenant ?? "",
            secrets: opts.secrets ?? { access_token: "AT-secret", refresh_token: SECRET },
          },
          error: null,
        });
      }
      if (fn === "revoke_accounting_connection_v1") {
        return Promise.resolve(opts.revokeFails
          ? { data: null, error: { code: "XX000" } }
          : { data: { id: CONN, status: "revoked" }, error: null });
      }
      if (fn === "set_accounting_credentials") return Promise.resolve({ data: { id: CONN }, error: null });
      return Promise.resolve({ data: null, error: { code: "42883" } });
    },
  });
  const deps: Deps = {
    caller: () => ({ ...answer("caller"), from: () => ({ select: () => ({ in: () => Promise.resolve({ data: null, error: null }) }) }) }),
    service: () => answer("service"),
    env: (name) =>
      ({
        [`ACCOUNTING_${target.toUpperCase()}_CLIENT_ID`]: "app-id",
        [`ACCOUNTING_${target.toUpperCase()}_CLIENT_SECRET`]: "app-secret",
      } as Record<string, string>)[name],
    redirectUri: "https://x.test/functions/v1/accounting-connect",
    fetcher: ((url: string | URL | Request, init?: RequestInit) => {
      seen.push({ url: String(url), init: init! });
      calls.push({ as: "vendor", fn: String(url), args: {} });
      return Promise.resolve(opts.vendor?.(new URL(String(url)), init!) ?? new Response("{}", { status: 200 }));
    }) as typeof fetch,
    now: () => new Date("2026-10-25T10:00:00Z"),
  };
  return { deps, calls, seen };
}

const post = (body: unknown) =>
  new Request("https://x.test/functions/v1/accounting-connect", {
    method: "POST",
    headers: { Authorization: "Bearer user-token", "content-type": "application/json" },
    body: JSON.stringify(body),
  });

Deno.test("revoking an OAuth connection revokes the refresh token at the target, after it is revoked here", async () => {
  const w = world();
  const res = await handle(post({ action: "revoke", connection_id: CONN }), w.deps);
  assertEquals(res.status, 200);
  const answer = await res.json();
  assertEquals(answer.connection, { id: CONN, status: "revoked" });
  assertEquals(answer.remote_revocation, "revoked");
  const order = w.calls.map((c) => c.fn);
  assert(order.indexOf("revoke_accounting_connection_v1") < order.findIndex((f) => f.startsWith("https://")));
  assertEquals(w.calls.find((c) => c.fn === "revoke_accounting_connection_v1")!.as, "caller");
  assertEquals(new URLSearchParams(String(w.seen[0].init.body)).get("token"), SECRET);
  assert(!JSON.stringify(answer).includes(SECRET));
});

Deno.test("a target that refuses or is unreachable still leaves the connection revoked, the failure said", async () => {
  for (const vendor of [() => new Response('{"error":"server_error"}', { status: 500 })]) {
    const w = world({ vendor });
    const answer = await (await handle(post({ action: "revoke", connection_id: CONN }), w.deps)).json();
    assertEquals(answer.connection.status, "revoked");
    assertEquals(answer.remote_revocation, "failed");
    assert(!JSON.stringify(answer).includes(SECRET));
  }
  const down = world({ vendor: () => {
    throw new Error(`connect ${SECRET}`);
  } });
  const answer = await (await handle(post({ action: "revoke", connection_id: CONN }), down.deps)).json();
  assertEquals(answer.remote_revocation, "failed");
  assert(!JSON.stringify(answer).includes(SECRET));
});

Deno.test("a target without a revocation endpoint, or a token connection, is revoked here only, said", async () => {
  for (const w of [world({ target: "pennylane_api", authKind: "token" }), world({ target: "sage_business_cloud_gb" })]) {
    const answer = await (await handle(post({ action: "revoke", connection_id: CONN }), w.deps)).json();
    assertEquals(answer.connection.status, "revoked");
    assertEquals(answer.remote_revocation, "not_supported");
    assertEquals(w.seen.length, 0);
  }
});

Deno.test("a caller who may not manage the connection revokes nothing anywhere", async () => {
  const w = world({ allowed: false });
  const res = await handle(post({ action: "revoke", connection_id: CONN }), w.deps);
  assertEquals(res.status, 403);
  assertEquals(w.seen.length, 0);
  assert(!w.calls.some((c) => c.fn === "revoke_accounting_connection_v1"));
});

Deno.test("when the database cannot revoke, the target is not asked and the connection is not left connected", async () => {
  const w = world({ revokeFails: true });
  const res = await handle(post({ action: "revoke", connection_id: CONN }), w.deps);
  assertEquals(res.status, 500);
  assertEquals(w.seen.length, 0);
});

// ── the company a token reaches ────────────────────────────────────────────

const me = (id: unknown) => (url: URL) =>
  url.pathname.endsWith("/me") ? Response.json({ company: { id, name: "Acme" } }) : Response.json({ items: [] });

Deno.test("verify records the company a token reaches when none was named", async () => {
  const w = world({ target: "pennylane_api", authKind: "token", secrets: { access_token: "tok-1234567" }, vendor: me(4242) });
  const res = await handle(post({ action: "verify", connection_id: CONN }), w.deps);
  assertEquals(res.status, 200);
  assertEquals((await res.json()).status, "verified");
  const written = w.calls.find((c) => c.fn === "set_accounting_credentials")!;
  assertEquals(written.args.p_patch, { remote_tenant_id: "4242" });
});

Deno.test("verify refuses a token that reaches another company than the one named, and says so", async () => {
  const w = world({ target: "pennylane_api", authKind: "token", tenant: "1111", secrets: { access_token: "tok-1234567" }, vendor: me(4242) });
  const res = await handle(post({ action: "verify", connection_id: CONN }), w.deps);
  assertEquals(res.status, 409);
  const written = w.calls.find((c) => c.fn === "set_accounting_credentials")!;
  assertEquals((written.args.p_patch as Record<string, string>).status, "error");
  assertEquals((written.args.p_patch as Record<string, string>).remote_tenant_id, undefined);
});

Deno.test("verify of the named company changes nothing", async () => {
  const w = world({ target: "pennylane_api", authKind: "token", tenant: "4242", secrets: { access_token: "tok-1234567" }, vendor: me(4242) });
  const res = await handle(post({ action: "verify", connection_id: CONN }), w.deps);
  assertEquals((await res.json()).status, "verified");
  assert(!w.calls.some((c) => c.fn === "set_accounting_credentials"));
});
