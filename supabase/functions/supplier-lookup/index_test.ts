// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2863 — what VIES answers becomes the neutral contract with two separate
// verdicts, every failure class is its own outcome, nothing undisclosed is
// invented, and the handler's own checks (shape, size, rate) refuse before
// anything leaves.
import { assertEquals } from "jsr:@std/assert@1";
import { askVies, splitAddress, VIES_MAX_RESPONSE_BYTES } from "./vies.ts";
import { parseLookupRequest, RateLimiter } from "./index.ts";

const request = {
  country_code: "FR",
  identifier: "11223344556",
  kind: "vat" as const,
  mode: "identifier" as const,
};
const at = () => new Date("2026-05-13T08:00:00Z");

const answering = (status: number, body: unknown, seen?: unknown[]) =>
  ((_url: string | URL | Request, init?: RequestInit) => {
    seen?.push(JSON.parse(String(init?.body)));
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  }) as typeof fetch;

Deno.test("a valid number with a disclosed profile is retrieved and validated", async () => {
  const seen: unknown[] = [];
  const result = await askVies(request, answering(200, {
    valid: true,
    requestIdentifier: "WAPIAAAAZ1",
    name: "ATELIER DES ARCEAUX SAS",
    address: "7 RUE DES ARCEAUX\n34000 MONTPELLIER",
  }, seen), at);
  assertEquals(seen[0], { countryCode: "FR", vatNumber: "11223344556" });
  assertEquals(result, {
    provider: "vies",
    looked_up_at: "2026-05-13T08:00:00.000Z",
    retrieval: "retrieved",
    validation: "validated",
    fields: {
      country_code: "FR",
      name: "ATELIER DES ARCEAUX SAS",
      street: "7 RUE DES ARCEAUX",
      postal_code: "34000",
      city: "MONTPELLIER",
    },
    reference: "WAPIAAAAZ1",
    detail: "",
  });
});

Deno.test("a member state that discloses nothing validates and returns no profile", async () => {
  const result = await askVies(
    { ...request, country_code: "DE", identifier: "123456789" },
    answering(200, { valid: true, requestIdentifier: "", name: "---", address: "---" }),
    at,
  );
  assertEquals(result.retrieval, "not_returned");
  assertEquals(result.validation, "validated");
  assertEquals(result.fields, { country_code: "DE" });
});

Deno.test("an invalid number is a verdict on the identifier, not an outage", async () => {
  const result = await askVies(request, answering(200, { valid: false, requestIdentifier: "" }), at);
  assertEquals(result.retrieval, "not_found");
  assertEquals(result.validation, "invalid");
  assertEquals(result.fields, {});
});

Deno.test("each VIES error code is its own outcome", async () => {
  const cases: [string, string, string][] = [
    ["INVALID_INPUT", "invalid_input", "not_validated"],
    ["MS_UNAVAILABLE", "unavailable", "unavailable"],
    ["SERVICE_UNAVAILABLE", "unavailable", "unavailable"],
    ["MS_MAX_CONCURRENT_REQ", "throttled", "unavailable"],
    ["GLOBAL_MAX_CONCURRENT_REQ", "throttled", "unavailable"],
    ["TIMEOUT", "timeout", "unavailable"],
  ];
  for (const [error, retrieval, validation] of cases) {
    const result = await askVies(request, answering(200, {
      actionSucceed: false,
      errorWrappers: [{ error }],
    }), at);
    assertEquals([result.retrieval, result.validation, result.detail], [retrieval, validation, error]);
  }
});

Deno.test("no answer, a timeout and an unreadable answer are told apart", async () => {
  const down = await askVies(request, (() => Promise.reject(new Error("down"))) as typeof fetch, at);
  assertEquals(down.retrieval, "unavailable");
  const aborted = await askVies(
    request,
    (() => Promise.reject(new DOMException("aborted", "AbortError"))) as typeof fetch,
    at,
  );
  assertEquals(aborted.retrieval, "timeout");
  const garbage = await askVies(
    request,
    (() => Promise.resolve(new Response("<html>", { status: 200 }))) as typeof fetch,
    at,
  );
  assertEquals(garbage.retrieval, "malformed");
  const huge = await askVies(
    request,
    (() =>
      Promise.resolve(
        new Response(JSON.stringify({ valid: true, name: "x".repeat(VIES_MAX_RESPONSE_BYTES) }), {
          status: 200,
        }),
      )) as typeof fetch,
    at,
  );
  assertEquals(huge.retrieval, "malformed");
  const http = await askVies(request, answering(503, {}), at);
  assertEquals(http.retrieval, "unavailable");
  const busy = await askVies(request, answering(429, {}), at);
  assertEquals(busy.retrieval, "throttled");
});

Deno.test("an address is split only where its last line reads as postal code and city", () => {
  assertEquals(splitAddress("12 AVENUE DE VERDUN\n34500 BEZIERS"), {
    street: "12 AVENUE DE VERDUN",
    postal_code: "34500",
    city: "BEZIERS",
  });
  assertEquals(splitAddress("KEIZERSGRACHT 1\n1015 AA AMSTERDAM"), {
    street: "KEIZERSGRACHT 1",
    postal_code: "1015 AA",
    city: "AMSTERDAM",
  });
  assertEquals(splitAddress("VIA ROMA 1, ROMA"), { street: "VIA ROMA 1, ROMA" });
  assertEquals(splitAddress("---"), {});
  assertEquals(splitAddress(""), {});
});

Deno.test("the request is checked for shape before anything leaves", () => {
  const ws = "0b8a6a4e-5c2f-4c7b-9d1e-2f3a4b5c6d7e";
  const ok = parseLookupRequest({
    workspace_id: ws,
    provider: "vies",
    kind: "vat",
    mode: "identifier",
    country_code: "fr",
    identifier: " 11 223.344-556 ",
  });
  assertEquals("error" in ok, false);
  if (!("error" in ok)) {
    assertEquals(ok.request, { country_code: "FR", identifier: "11223344556", kind: "vat", mode: "identifier" });
  }
  const refused = (body: unknown) => (parseLookupRequest(body) as { error?: string }).error;
  assertEquals(refused(null), "invalid body");
  assertEquals(refused({ provider: "vies" }), "workspace_id required");
  assertEquals(refused({ workspace_id: ws, provider: "registry-x" }), "unknown provider");
  assertEquals(refused({ workspace_id: ws, provider: "vies", kind: "registration", mode: "identifier" }), "unsupported identifier kind");
  assertEquals(refused({ workspace_id: ws, provider: "vies", kind: "vat", mode: "name" }), "unsupported lookup mode");
  assertEquals(refused({ workspace_id: ws, provider: "vies", kind: "vat", mode: "identifier", country_code: "FRA" }), "country_code must be two letters");
  assertEquals(
    refused({ workspace_id: ws, provider: "vies", kind: "vat", mode: "identifier", country_code: "FR", identifier: "1" }),
    "identifier must be 2-20 letters or digits",
  );
  assertEquals(
    refused({ workspace_id: ws, provider: "vies", kind: "vat", mode: "identifier", country_code: "FR", identifier: "12; drop table" }),
    "identifier must be 2-20 letters or digits",
  );
});

Deno.test("a caller is throttled after the window's quota, and recovers", () => {
  const limiter = new RateLimiter(2, 1000);
  assertEquals(limiter.allow("a", 0), true);
  assertEquals(limiter.allow("a", 10), true);
  assertEquals(limiter.allow("a", 20), false);
  assertEquals(limiter.allow("b", 20), true);
  assertEquals(limiter.allow("a", 1011), true);
});
