// SPDX-License-Identifier: AGPL-3.0-or-later
// #4412 -- the invariant: an edge function answers one envelope (a stable code and words safe to show), a failure
// never carries the error's own words, the logger keeps secrets, personal data and cycles out of its lines, and a
// request id is never echoed raw.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { fail, INTERNAL_ERROR, ok, refuse } from "./respond.ts";
import { describeError, redactFields, scrub } from "./log.ts";
import { guard } from "./serve.ts";

const quietly = async <T>(run: () => Promise<T> | T): Promise<{ result: T; lines: string[] }> => {
  const lines: string[] = [];
  const saved = console.error;
  console.error = (line: string) => lines.push(String(line));
  try {
    return { result: await run(), lines };
  } finally {
    console.error = saved;
  }
};

Deno.test("#4412 ok answers its body as JSON with the CORS headers", async () => {
  const response = ok({ a: 1 }, 201);
  assertEquals(response.status, 201);
  assertEquals(await response.json(), { a: 1 });
  assertEquals(response.headers.get("Content-Type"), "application/json");
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("#4412 a refusal is the envelope: a stable code, words safe to show", async () => {
  const response = refuse("not_allowed", 403, "ask the owner", { field: "x" });
  assertEquals(response.status, 403);
  assertEquals(await response.json(), { error: "not_allowed", detail: "ask the owner", field: "x" });
  assertEquals(await refuse("gone", 410).json(), { error: "gone" });
});

Deno.test("#4412 a failure answers the code and the request id, never the error", async () => {
  const { result, lines } = await quietly(() =>
    fail(new Error("connect ECONNREFUSED 10.0.0.1 with Bearer abc.def.ghi"), { fn: "demo", requestId: "r-1" })
  );
  assertEquals(result.status, 500);
  const body = await result.json();
  assertEquals(body, { error: INTERNAL_ERROR, request_id: "r-1" });
  assert(!JSON.stringify(body).includes("ECONNREFUSED"));
  assertEquals(lines.length, 1);
  const line = JSON.parse(lines[0]);
  assertEquals([line.level, line.fn, line.code, line.request_id], ["error", "demo", INTERNAL_ERROR, "r-1"]);
  assert(line.error.message.includes("ECONNREFUSED"), "the log keeps what the answer does not");
  assert(!line.error.message.includes("abc.def.ghi"), "but not a credential");
});

Deno.test("#4412 guard turns an uncaught error into the envelope", async () => {
  const handler = guard("demo", () => {
    throw new Error("internal detail");
  });
  const { result } = await quietly(() => handler(new Request("https://x.test/", { headers: { "x-request-id": "r-2" } })));
  assertEquals(result.status, 500);
  assertEquals(await result.json(), { error: INTERNAL_ERROR, request_id: "r-2" });
  const fine = guard("demo", () => ok({ fine: true }));
  assertEquals(await (await fine(new Request("https://x.test/"))).json(), { fine: true });
});

Deno.test("#4412 a log line leaves secrets and long strings out", () => {
  const out = redactFields({ authorization: "Bearer x", api_key: "k", nested: { token: "t", n: 1 }, note: "y".repeat(400), ok: "fine" });
  assertEquals(out.authorization, "[redacted]");
  assertEquals(out.api_key, "[redacted]");
  assertEquals(out.nested, { token: "[redacted]", n: 1 });
  assertEquals((out.note as string).length, 303);
  assertEquals(out.ok, "fine");
  assertEquals(scrub("https://h.test/p?api_key=SECRET&x=1"), "https://h.test/p?api_key=[redacted]&x=1");
  assertEquals(describeError("plain").name, "string");
});
