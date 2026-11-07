// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 — what each provider declares, pinned as literal expectations. The
// tables below were copied from the switches of connectors.ts BEFORE they were
// replaced by a registry of connector records; this file must pass unchanged
// on both sides of that refactor, which is the proof that no provider's
// required fields, accepted syntaxes or sandbox moved.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  acceptedFormats,
  isProvider,
  PROVIDERS,
  requiredFields,
  SANDBOX,
  status,
  submit,
} from "./connectors.ts";

const REQUIRED: Record<string, string[]> = {
  generic: ["endpoint", "auth_value"],
  peppol: ["base_url", "api_key", "legal_entity_id"],
  fr_pa: ["base_url", "token_url", "client_id", "client_secret"],
  it_sdi: ["base_url", "login_url", "username", "password"],
  pl_ksef: ["base_url", "nip", "ksef_token"],
  ro_efactura: ["base_url", "cif", "access_token"],
};

const ACCEPTED: Record<string, string[]> = {
  generic: [],
  peppol: ["peppolBis", "xrechnung"],
  fr_pa: ["en16931Cii", "facturX", "en16931Ubl"],
  it_sdi: ["fatturaPa"],
  pl_ksef: ["ksefFa3"],
  ro_efactura: ["ciusRo"],
};

const SANDBOXES: Record<string, Record<string, string>> = {
  generic: {},
  peppol: { base_url: "https://api.storecove.com" },
  fr_pa: {},
  it_sdi: {
    base_url: "https://api-sandbox.acubeapi.com",
    login_url: "https://common-sandbox.api.acubeapi.com/login",
  },
  pl_ksef: { base_url: "https://ksef-test.mf.gov.pl/api/v2" },
  ro_efactura: { base_url: "https://api.anaf.ro/test/FCTEL/rest" },
};

Deno.test("the provider list is the six it always was, in order", () => {
  assertEquals([...PROVIDERS], [
    "generic",
    "peppol",
    "fr_pa",
    "it_sdi",
    "pl_ksef",
    "ro_efactura",
  ]);
  for (const p of PROVIDERS) assert(isProvider(p));
  assert(!isProvider("nl_peppol"));
});

Deno.test("each provider declares the fields, syntaxes and sandbox it did", () => {
  for (const p of PROVIDERS) {
    assertEquals(requiredFields(p), REQUIRED[p], `${p} required`);
    assertEquals(acceptedFormats(p), ACCEPTED[p], `${p} accepted`);
    assertEquals({ ...SANDBOX[p] }, SANDBOXES[p], `${p} sandbox`);
  }
});

Deno.test("an unknown provider is treated as the generic upload, as before", () => {
  assertEquals(requiredFields("unknown"), REQUIRED.generic);
  assertEquals(acceptedFormats("unknown"), []);
});

Deno.test("a document in a syntax the provider does not take is refused before anything leaves", async () => {
  let calls = 0;
  const fetchImpl = (() => {
    calls++;
    return Promise.resolve(new Response("{}"));
  }) as unknown as typeof fetch;
  const doc = {
    fileName: "F-1.xml",
    mimeType: "application/xml",
    bytes: new TextEncoder().encode("<x/>"),
    format: "peppolBis",
    number: "F-1",
    receiver: { scheme: "0208", id: "1" },
  };
  const out = await submit("it_sdi", {}, doc, fetchImpl);
  assertEquals(out.status, "failed");
  assertEquals(
    out.detail,
    "it_sdi does not accept peppolBis (it takes fatturaPa)",
  );
  assertEquals(calls, 0);
});

Deno.test("the generic upload has no status read-back", async () => {
  const out = await status("generic", {}, "ext-1");
  assertEquals(out.status, "failed");
  assertEquals(out.detail, "the generic upload has no status read-back");
  assertEquals(out.externalId, "ext-1");
});
