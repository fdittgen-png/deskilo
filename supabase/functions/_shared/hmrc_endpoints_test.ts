// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — which HMRC the installation talks to: the installation only chooses
// an environment, the hosts are exact approved origins, and nothing else (no
// client value, wildcard or suffix) ever builds a URL.
import { assertEquals } from "jsr:@std/assert@1";
import { hmrcEndpoints, isApprovedHmrcUrl } from "./hmrc_endpoints.ts";

const envOf = (v?: string) => (name: string) =>
  name === "HMRC_ENVIRONMENT" ? v : undefined;

Deno.test("the installation chooses an environment; the hosts are fixed", () => {
  assertEquals(hmrcEndpoints(envOf("sandbox")), {
    api: "https://test-api.service.hmrc.gov.uk",
    signIn: "https://test-www.tax.service.gov.uk",
  });
  assertEquals(
    hmrcEndpoints(envOf(" Production "))?.signIn,
    "https://www.tax.service.gov.uk",
  );
});

Deno.test("nothing chosen, or anything else, is not configured", () => {
  for (
    const v of [
      undefined,
      "",
      "staging",
      "https://evil.example",
      "__proto__",
      "constructor",
    ]
  ) {
    assertEquals(hmrcEndpoints(envOf(v)), null, String(v));
  }
});

Deno.test("only the exact approved origins pass", () => {
  assertEquals(
    isApprovedHmrcUrl("https://test-api.service.hmrc.gov.uk/oauth/token"),
    true,
  );
  assertEquals(
    isApprovedHmrcUrl("https://www.tax.service.gov.uk/oauth/authorize"),
    true,
  );
  for (
    const bad of [
      "http://api.service.hmrc.gov.uk/x",
      "https://api.service.hmrc.gov.uk.evil.example/x",
      "https://evil.service.gov.uk/x",
      "https://user:pw@api.service.hmrc.gov.uk/x",
      "https://api.service.hmrc.gov.uk:8443/x",
      "//api.service.hmrc.gov.uk/x",
      "not a url",
    ]
  ) assertEquals(isApprovedHmrcUrl(bad), false, bad);
});
