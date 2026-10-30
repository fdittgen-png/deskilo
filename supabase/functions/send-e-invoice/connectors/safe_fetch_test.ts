// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3090 — the destination check: nothing but a public https host is called,
// before any request leaves; a redirect is refused; the client never reads a
// provider's own words.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  assertPublicUrl,
  clientDetail,
  DestinationRefused,
  isPublicAddress,
  safeFetch,
} from "./safe_fetch.ts";

const resolver = (table: Record<string, string[]>) => (host: string) =>
  Promise.resolve(table[host] ?? []);

Deno.test("only a public https destination passes", async () => {
  const resolve = resolver({
    "api.example.com": ["93.184.216.34"],
    "rebind.example.com": ["10.0.0.7"],
    "mixed.example.com": ["93.184.216.34", "169.254.169.254"],
  });
  await assertPublicUrl("https://api.example.com/upload", resolve);
  for (
    const url of [
      "http://api.example.com/upload",
      "https://127.0.0.1/x",
      "https://localhost/x",
      "https://169.254.169.254/latest/meta-data",
      "https://10.0.0.1/x",
      "https://172.20.1.1/x",
      "https://192.168.1.1/x",
      "https://[::1]/x",
      "https://[fd00::1]/x",
      "https://[::ffff:10.0.0.1]/x",
      "https://rebind.example.com/x",
      "https://mixed.example.com/x",
      "https://unknown.example.com/x",
      "ftp://api.example.com/x",
      "not a url",
    ]
  ) {
    await assertRejects(
      () => assertPublicUrl(url, resolve),
      DestinationRefused,
      "destination_not_allowed",
      url,
    );
  }
});

Deno.test("a refused destination never reaches the network", async () => {
  let calls = 0;
  const guarded = safeFetch(
    () => {
      calls++;
      return Promise.resolve(new Response("ok"));
    },
    resolver({ "api.example.com": ["93.184.216.34"] }),
  );
  await assertRejects(() => guarded("https://10.0.0.1/x"));
  await assertRejects(() => guarded("http://api.example.com/x"));
  assertEquals(calls, 0);
  const ok = await guarded("https://api.example.com/x");
  assertEquals(await ok.text(), "ok");
  assertEquals(calls, 1);
});

Deno.test("a redirect is refused, not followed", async () => {
  const guarded = safeFetch(
    () =>
      Promise.resolve(
        new Response(null, {
          status: 302,
          headers: { location: "https://169.254.169.254/" },
        }),
      ),
    resolver({ "api.example.com": ["93.184.216.34"] }),
  );
  await assertRejects(
    () => guarded("https://api.example.com/x"),
    DestinationRefused,
    "redirect_refused",
  );
});

Deno.test("address classes", () => {
  for (const ip of ["8.8.8.8", "93.184.216.34", "2606:4700::1111"]) {
    assert(isPublicAddress(ip), ip);
  }
  for (
    const ip of [
      "0.0.0.0",
      "100.64.0.1",
      "198.18.0.1",
      "224.0.0.1",
      "255.255.255.255",
      "fe80::1",
      "ff02::1",
    ]
  ) {
    assert(!isPublicAddress(ip), ip);
  }
});

Deno.test("the client reads a fixed key, never the provider's words", () => {
  assertEquals(clientDetail("accepted", "id=42"), "");
  assertEquals(
    clientDetail("rejected", "403 secret internal body"),
    "provider_rejected",
  );
  assertEquals(
    clientDetail("failed", "connect ECONNREFUSED 10.0.0.5"),
    "provider_unreachable",
  );
  assertEquals(
    clientDetail("failed", "destination_not_allowed"),
    "destination_not_allowed",
  );
});
