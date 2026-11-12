// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 -- badge sign-in on an enrolled kiosk and elsewhere. The function
// passes the device's credential to the database and says a name at the
// scan only when the database gives one; a missing or malformed credential
// is no device. The database's own rules (which device counts, the setting,
// the pause) are pgTAP 400's.
import { assertEquals } from "jsr:@std/assert@1";
import { handle } from "./handler.ts";
import { KIOSK_HEADER } from "./badge_guard.ts";

const DEVICE = "00000000-0000-4000-8000-000000003675";
const CREDENTIAL = "ab".repeat(32);
const UID = "04a1b2c3d4e5f6";

type Args = Record<string, unknown>;

/** A database that answers by the device it was given. */
function db(answer: (args: Args) => Record<string, unknown>) {
  const calls: Args[] = [];
  return {
    calls,
    deps: {
      rpc: (_fn: string, args: Args) => {
        calls.push(args);
        return Promise.resolve({ data: answer(args), error: null });
      },
      emailOf: () => Promise.resolve("member@example.test"),
      tokenFor: () => Promise.resolve("hashed-token"),
    },
  };
}

const post = (body: unknown, headers: Record<string, string> = {}) =>
  new Request("http://x", { method: "POST", body: JSON.stringify(body), headers });

const kiosk = { [KIOSK_HEADER]: `${DEVICE}.${CREDENTIAL}` };

Deno.test("an enrolled kiosk's credential reaches the database on both steps", async () => {
  const d = db(() => ({ ok: true, user_id: "u1" }));
  await handle(post({ uid: UID }, kiosk), d.deps);
  await handle(post({ uid: UID, pin: "123456" }, kiosk), d.deps);
  for (const c of d.calls) {
    assertEquals([c.p_device_id, c.p_device_secret], [DEVICE, CREDENTIAL]);
  }
});

Deno.test("on a kiosk the scan names the person the database names; elsewhere nobody", async () => {
  const named = db((a) => (a.p_device_id ? { ok: true, display_name: "Ana Martin" } : { ok: true }));
  const onKiosk = await (await handle(post({ uid: UID }, kiosk), named.deps)).json();
  assertEquals(onKiosk, { ok: true, step: "identify", display_name: "Ana Martin", has_avatar: false });
  const elsewhere = await (await handle(post({ uid: UID }), named.deps)).json();
  assertEquals(elsewhere, { ok: true, step: "identify", display_name: "", has_avatar: false });
});

Deno.test("a revoked or foreign device: the database names nobody, and nor does the function", async () => {
  // The database treats such a device as none: it answers as without one.
  const d = db(() => ({ ok: true }));
  const res = await (await handle(post({ uid: UID }, kiosk), d.deps)).json();
  assertEquals(res.display_name, "");
});

Deno.test("a malformed kiosk header is no device, not a refusal", async () => {
  const d = db(() => ({ ok: true }));
  for (const value of ["", "nonsense", `${DEVICE}.short`, `${DEVICE}`, `not-a-uuid.${CREDENTIAL}`]) {
    const res = await handle(post({ uid: UID }, { [KIOSK_HEADER]: value }), d.deps);
    assertEquals((await res.json()).ok, true);
  }
  assertEquals(d.calls.every((c) => c.p_device_id === null && c.p_device_secret === null), true);
});

Deno.test("the PIN step: a refusal and a lock answer alike on a kiosk and elsewhere; a match gives a token", async () => {
  for (const headers of [kiosk, {}]) {
    const refusedDb = db(() => ({ ok: false, reason: "refused" }));
    assertEquals(await (await handle(post({ uid: UID, pin: "123456" }, headers), refusedDb.deps)).json(),
      { ok: false, reason: "refused" });
    const lockedDb = db(() => ({ ok: false, reason: "locked" }));
    assertEquals(await (await handle(post({ uid: UID, pin: "123456" }, headers), lockedDb.deps)).json(),
      { ok: false, reason: "locked" });
  }
  const ok = db(() => ({ ok: true, user_id: "u1", display_name: "Ana Martin" }));
  assertEquals(await (await handle(post({ uid: UID, pin: "123456" }, kiosk), ok.deps)).json(),
    { ok: true, step: "authenticate", token_hash: "hashed-token" });
});

Deno.test("a browser kiosk may send its header: the preflight allows it", async () => {
  const res = await handle(new Request("http://x", { method: "OPTIONS" }), db(() => ({})).deps);
  assertEquals(res.headers.get("Access-Control-Allow-Headers")?.includes(KIOSK_HEADER), true);
});
