// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The sign-in round trip with the database and the token endpoint played:
// who may start it, that nothing opens without an OAuth application, that
// the redirect is checked against the state in Vault, that tokens go to
// Vault and never into an answer, and that a refused refresh expires the
// connection.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { type Deps, handle } from "./index.ts";

const WS = "11111111-1111-4111-8111-111111111111";
const SITE = "22222222-2222-4222-8222-222222222222";
const CONN = "33333333-3333-4333-8333-333333333333";

type Call = { as: string; fn: string; args: Record<string, unknown> };

function world(opts: { configured?: boolean; allowed?: boolean; token?: (body: URLSearchParams) => Response } = {}) {
  const calls: Call[] = [];
  const vault: Record<string, string> = {};
  let state: Record<string, unknown> = { status: "pending" };
  const answer = (as: string) => ({
    rpc: (fn: string, args: Record<string, unknown>) => {
      calls.push({ as, fn, args });
      if (fn === "open_accounting_connection_v1" || fn === "accounting_connection_manageable_v1") {
        return Promise.resolve(opts.allowed === false
          ? { data: null, error: { code: "42501" } }
          : { data: { id: CONN, target_id: "pennylane_api", auth_kind: "oauth2", status: "pending" }, error: null });
      }
      if (fn === "accounting_credentials_resolved") {
        return Promise.resolve({
          data: { id: CONN, target_id: "pennylane_api", auth_kind: "oauth2", revoked: false, secrets: { ...vault } },
          error: null,
        });
      }
      if (fn === "set_accounting_credentials") {
        for (const [k, v] of Object.entries(args.p_secrets as Record<string, string>)) {
          if (v) vault[k] = v;
          else delete vault[k];
        }
        state = { ...state, ...(args.p_patch as Record<string, unknown>) };
        return Promise.resolve({ data: { id: CONN }, error: null });
      }
      return Promise.resolve({ data: null, error: { code: "42883" } });
    },
  });
  const deps: Deps = {
    caller: () => answer("caller"),
    service: () => answer("service"),
    env: (name) => opts.configured === false ? undefined : ({
      ACCOUNTING_PENNYLANE_API_CLIENT_ID: "app-id",
      ACCOUNTING_PENNYLANE_API_CLIENT_SECRET: "app-secret",
    } as Record<string, string>)[name],
    redirectUri: "https://x.test/functions/v1/accounting-connect",
    fetcher: ((_url: string | URL | Request, init?: RequestInit) =>
      Promise.resolve(
        opts.token
          ? opts.token(new URLSearchParams(String(init?.body)))
          : new Response(JSON.stringify({ access_token: "AT-secret", refresh_token: "RT-secret", expires_in: 60 })),
      )) as typeof fetch,
    now: () => new Date("2026-10-25T10:00:00Z"),
  };
  return { deps, calls, vault, state: () => state };
}

const post = (body: unknown, auth = "Bearer user-token") =>
  new Request("https://x.test/functions/v1/accounting-connect", {
    method: "POST",
    headers: { Authorization: auth, "content-type": "application/json" },
    body: JSON.stringify(body),
  });

const start = { action: "authorize", workspace_id: WS, issuer_site_id: SITE, target_id: "pennylane_api", display_name: "Pennylane" };

async function signIn(w: ReturnType<typeof world>): Promise<string> {
  const res = await handle(post(start), w.deps);
  assertEquals(res.status, 200);
  const url = new URL((await res.json()).authorize_url);
  return url.searchParams.get("state")!;
}

Deno.test("authorize opens the connection as the caller and keeps the state in Vault", async () => {
  const w = world();
  const state = await signIn(w);
  const open = w.calls.find((c) => c.fn === "open_accounting_connection_v1")!;
  assertEquals(open.as, "caller");
  assertEquals(open.args.p_auth_kind, "oauth2");
  assertEquals(state, `${CONN}.${w.vault.oauth_state}`);
});

Deno.test("no OAuth application on this server: nothing is opened", async () => {
  const w = world({ configured: false });
  const res = await handle(post(start), w.deps);
  assertEquals(res.status, 503);
  assertEquals(await res.json(), { error: "oauth_not_configured" });
  assertEquals(w.calls.length, 0);
});

Deno.test("a caller the database refuses opens nothing and learns nothing", async () => {
  const w = world({ allowed: false });
  const res = await handle(post(start), w.deps);
  assertEquals(res.status, 403);
  assertEquals(Object.keys(w.vault).length, 0);
});

Deno.test("the redirect exchanges the code, stores the tokens in Vault and answers no token", async () => {
  const w = world();
  const state = await signIn(w);
  const res = await handle(new Request(`https://x.test/functions/v1/accounting-connect?code=C0DE&state=${state}`), w.deps);
  assertEquals(res.status, 200);
  const text = await res.text();
  assert(!text.includes("secret"));
  assertEquals(w.vault, { access_token: "AT-secret", refresh_token: "RT-secret" });
  assertEquals(w.state().status, "connected");
  assertEquals(w.state().token_expires_at, "2026-10-25T10:01:00.000Z");
});

Deno.test("a redirect with another state is refused before any exchange", async () => {
  const w = world();
  await signIn(w);
  let exchanged = false;
  w.deps.fetcher = (() => {
    exchanged = true;
    return Promise.resolve(new Response("{}"));
  }) as typeof fetch;
  const res = await handle(new Request(`https://x.test/functions/v1/accounting-connect?code=C&state=${CONN}.forged`), w.deps);
  assertEquals(res.status, 400);
  assert(!exchanged);
  assertEquals(w.state().status, "pending");
});

Deno.test("a refused exchange leaves the connection in error, said, and spends the state", async () => {
  const w = world({ token: () => new Response(JSON.stringify({ error: "invalid_grant" }), { status: 400 }) });
  const state = await signIn(w);
  const res = await handle(new Request(`https://x.test/functions/v1/accounting-connect?code=C&state=${state}`), w.deps);
  assertEquals(res.status, 502);
  assertEquals(w.state(), { status: "error", status_detail: "invalid_grant" });
  assertEquals(w.vault.oauth_state, undefined);
});

Deno.test("a refused refresh expires the connection and forgets its tokens", async () => {
  const w = world({ token: (body) =>
    body.get("grant_type") === "refresh_token"
      ? new Response(JSON.stringify({ error: "invalid_grant" }), { status: 400 })
      : new Response(JSON.stringify({ access_token: "AT", refresh_token: "RT" })) });
  const state = await signIn(w);
  await handle(new Request(`https://x.test/functions/v1/accounting-connect?code=C&state=${state}`), w.deps);
  const res = await handle(post({ action: "refresh", connection_id: CONN }), w.deps);
  assertEquals(await res.json(), { status: "expired" });
  assertEquals(w.vault, {});
  assertEquals(w.state().status, "expired");
  assertEquals(w.calls.find((c) => c.fn === "accounting_connection_manageable_v1")!.as, "caller");
});

Deno.test("a delegated token, no token, a bad body and an unknown action are refused", async () => {
  const w = world();
  const claims = btoa(JSON.stringify({ client_id: "assistant" }));
  assertEquals((await handle(post(start, `Bearer x.${claims}.y`), w.deps)).status, 403);
  assertEquals((await handle(post(start, ""), w.deps)).status, 401);
  const bad = new Request("https://x.test/f", { method: "POST", headers: { Authorization: "Bearer t" }, body: "[" });
  assertEquals((await handle(bad, w.deps)).status, 400);
  assertEquals((await handle(post({ action: "delete" }), w.deps)).status, 400);
  assertEquals((await handle(post({ ...start, target_id: "xero" }), w.deps)).status, 400);
  assertEquals(w.calls.length, 0);
});
