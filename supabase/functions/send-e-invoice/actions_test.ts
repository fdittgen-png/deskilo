// SPDX-License-Identifier: AGPL-3.0-or-later
import { assertEquals, assertStrictEquals } from "jsr:@std/assert@1";
import { ACTIONS, actionFor, SEND } from "./actions/index.ts";
import { handle } from "./handler.ts";
import type { TransmissionStore } from "./store.ts";

Deno.test("#4400 a name the table does not hold is a send, whatever Object.prototype holds", () => {
  for (const name of ["constructor", "toString", "__proto__", "hasOwnProperty", "valueOf", "unknown", "", undefined]) {
    assertStrictEquals(actionFor(name), SEND, String(name));
  }
  for (const name of Object.keys(ACTIONS)) assertStrictEquals(actionFor(name), ACTIONS[name], name);
});

Deno.test("#4400 an action named constructor is answered as a send is: its gates run", async () => {
  const calls: string[] = [];
  const store = {
    user: () => Promise.resolve("u1"),
    member: () => Promise.resolve({ id: "m1", status: "active", is_owner: true }),
    hasPermission: () => Promise.resolve(true),
    credentials: () => Promise.resolve(null),
    workspaceEnvironment: () => {
      calls.push("environment");
      return Promise.resolve("prod");
    },
    expire: () => {
      calls.push("expire");
      return Promise.resolve();
    },
  } as unknown as TransmissionStore;
  const answer = await handle(
    new Request("https://x.test/", {
      method: "POST",
      headers: { Authorization: "Bearer t" },
      body: JSON.stringify({ workspace_id: "w", action: "constructor" }),
    }),
    { store },
  );
  assertEquals(calls, ["environment", "expire"]);
  // no credentials: a send is not configured, as for any request that names no action
  assertEquals(answer.status, 409);
  assertEquals((await answer.json()).error, "not_configured");
});
