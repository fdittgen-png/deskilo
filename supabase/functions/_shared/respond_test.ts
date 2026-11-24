// SPDX-License-Identifier: AGPL-3.0-or-later
// #4412 -- the invariant: an edge function answers one envelope (a stable code and words safe to show), a failure
// never carries the error's own words, the logger keeps secrets, personal data and cycles out of its lines, and a
// request id is never echoed raw.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { fail, INTERNAL_ERROR, ok, refuse, refuseDb } from "./respond.ts";
import { describeError, logLine, redactFields, requestIdOf, scrub } from "./log.ts";
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
  assertEquals(describeError("plain").type, "string");
});

Deno.test("#4412 redaction reads arrays and nested objects, personal keys, e-mails and JWTs, and survives a cycle", () => {
  const out = redactFields({
    list: [{ token: "t", ok: 1 }, "mail me at ann@example.com", "eyJhbGciOi.eyJzdWIiOi.sig"],
    email: "ann@example.com",
    first_name: "Ann",
    name: "Ann",
    file_name: "x.pdf",
    nested: { deeper: { deepest: { deepest2: { x: 1 } } } },
  });
  assertEquals((out.list as unknown[])[0], { token: "[redacted]", ok: 1 });
  assertEquals((out.list as unknown[])[1], "mail me at [email]");
  assertEquals((out.list as unknown[])[2], "[jwt]");
  assertEquals([out.email, out.first_name, out.name], ["[redacted]", "[redacted]", "[redacted]"]);
  assertEquals(out.file_name, "x.pdf", "a key that only contains the word is not a personal one");
  assertEquals(JSON.stringify(out.nested).includes("\"x\""), false, "past the depth nothing is logged");
  const cyclic: Record<string, unknown> = { a: 1 };
  cyclic.self = cyclic;
  assertEquals((redactFields(cyclic).self as string), "[cycle]");
  const saved = console.log;
  const lines: string[] = [];
  console.log = (l: string) => lines.push(l);
  try {
    logLine("info", "demo", "c", { cyclic, big: 10n }, "r");
    logLine("info", "demo", "c", { f: () => 1 });
  } finally {
    console.log = saved;
  }
  assertEquals(lines.length, 2);
});

Deno.test("#4412 a request id is a UUID or a short safe string; client text is never echoed", () => {
  const withId = (id: string) => requestIdOf(new Request("https://x.test/", { headers: { "x-request-id": id } }));
  assertEquals(withId("8b8c1f0e-2f4e-4d2e-9d0e-0a1b2c3d4e5f"), "8b8c1f0e-2f4e-4d2e-9d0e-0a1b2c3d4e5f");
  assertEquals(withId("req_12:ab.c-9"), "req_12:ab.c-9");
  for (const bad of ["a".repeat(65), "has space", "<script>x</script>", "id\twith-tab"]) {
    const made = withId(bad);
    assertEquals(made === bad, false);
    assertEquals(/^[0-9a-f-]{36}$/.test(made), true);
  }
});

Deno.test("#4412 a huge text costs a bounded scrub and is clipped", () => {
  const started = performance.now();
  const huge = "a".repeat(2_000_000) + "@";
  const out = redactFields({ note: huge, list: [huge] });
  assertEquals((out.note as string).length, 303);
  assert(performance.now() - started < 500, "a large field is bounded before it is scrubbed");
  assertEquals(describeError(new Error(huge)).message.length, 303);
});

Deno.test("#4412 personal keys are read by their words: camelCase, separators and plurals", () => {
  const out = redactFields({
    vatId: 1, VATID: 1, "vat-id": 1, emailAddress: 1, fullName: 1, phone_number: 1, mobile: 1,
    username: 1, recipients: 1, Recipients: 1, userName: 1, file_name: "x.pdf", filename: "y", count: 2,
  });
  for (const k of ["vatId", "VATID", "vat-id", "emailAddress", "fullName", "phone_number", "mobile", "username", "recipients", "Recipients", "userName"]) {
    assertEquals(out[k], "[redacted]", k);
  }
  assertEquals([out.file_name, out.filename, out.count], ["x.pdf", "y", 2]);
});

Deno.test("#4412 a text loses URL credentials, query secrets and Basic credentials", () => {
  assertEquals(scrub("GET https://user:pass@host.test/p"), "GET https://[redacted]@host.test/p");
  assertEquals(scrub("https://h.test/p?x=1&access_token=abc&Api-Key=zzz&q=ok"), "https://h.test/p?x=1&access_token=[redacted]&Api-Key=[redacted]&q=ok");
  assertEquals(scrub("Authorization: Basic dXNlcjpwYXNz"), "Authorization: Basic [redacted]");
});

Deno.test("#4412 describeError never throws and a field cannot override what identifies a line", () => {
  const unprintable = { toString() { throw new Error("no"); } };
  assertEquals(describeError(unprintable).message, "[unprintable]");
  const odd = new Error("m");
  odd.name = "N" + "x".repeat(500) + " Bearer abc";
  assertEquals(describeError(odd).type.length <= 303, true);
  assertEquals(describeError(odd).type.includes("abc"), false);
  const saved = console.log;
  const lines: string[] = [];
  console.log = (l: string) => lines.push(l);
  try {
    logLine("info", "real_fn", "real_code", { level: "error", fn: "spoof", code: "spoof", request_id: "spoof" }, "r-9");
  } finally {
    console.log = saved;
  }
  const line = JSON.parse(lines[0]);
  assertEquals([line.level, line.fn, line.code, line.request_id], ["info", "real_fn", "real_code", "r-9"]);
});

Deno.test("#4412 a database refusal says its own sentence only for a DK code", async () => {
  const ours = await refuseDb({ code: "DKP04", message: "the order changed" }, 409).json();
  assertEquals(ours, { error: "the order changed", code: "DKP04" });
  const raw = await refuseDb({ code: "42P01", message: 'relation "x" does not exist' }, 400).json();
  assertEquals(raw, { error: "refused", code: "42P01" });
});
