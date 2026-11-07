// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3338 — a country's provider is retired and everything else keeps working.
// The registry is built WITHOUT the Italian connector; the other connectors,
// the shared helpers and the generic upload behave as before, and a stored
// it_sdi submission is answered with an explicit refusal, never a throw and
// never a fallback to another provider.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildRegistry } from "./connectors.ts";
import { frPaConnector } from "./connectors/fr_pa.ts";
import { genericConnector } from "./connectors/generic.ts";
import { peppolConnector } from "./connectors/peppol.ts";
import { plKsefConnector } from "./connectors/pl_ksef.ts";
import { roEfacturaConnector } from "./connectors/ro_efactura.ts";

const withoutItaly = buildRegistry([
  genericConnector,
  peppolConnector,
  frPaConnector,
  plKsefConnector,
  roEfacturaConnector,
]);

let sent = 0;
const counting = (() => {
  sent++;
  return Promise.resolve(new Response("{}", { status: 200 }));
}) as unknown as typeof fetch;

const doc = (format: string) => ({
  fileName: "F-1.xml",
  mimeType: "application/xml",
  bytes: new TextEncoder().encode("<Invoice/>"),
  format,
  number: "F-1",
  receiver: { scheme: "0208", id: "0202239951" },
});

Deno.test("the registry without Italy lists the other five and no Italian field", () => {
  assertEquals([...withoutItaly.providers], [
    "generic",
    "peppol",
    "fr_pa",
    "pl_ksef",
    "ro_efactura",
  ]);
  assert(!withoutItaly.providers.includes("it_sdi"));
});

Deno.test("a retired provider's submission is refused with nothing sent", async () => {
  sent = 0;
  const out = await withoutItaly.submit(
    "it_sdi",
    { endpoint: "https://example.test", auth_value: "x" },
    doc("fatturaPa"),
    counting,
  );
  assertEquals(out.status, "failed");
  assertEquals(out.detail, "no connector is installed for it_sdi");
  assertEquals(sent, 0, "no fallback to the generic upload");
});

Deno.test("a stored it_sdi id read back without the connector is an explicit refusal", async () => {
  sent = 0;
  const out = await withoutItaly.status("it_sdi", {}, "uuid-1", counting);
  assertEquals(out.status, "failed");
  assertEquals(out.externalId, "uuid-1");
  assertEquals(out.detail, "no connector is installed for it_sdi");
  assertEquals(sent, 0);
});

Deno.test("the other providers still refuse a foreign syntax and still send their own", async () => {
  sent = 0;
  const refused = await withoutItaly.submit(
    "ro_efactura",
    {},
    doc("fatturaPa"),
    counting,
  );
  assertEquals(refused.status, "failed");
  assertEquals(
    refused.detail,
    "ro_efactura does not accept fatturaPa (it takes ciusRo)",
  );
  assertEquals(sent, 0);
  const generic = await withoutItaly.submit(
    "generic",
    { endpoint: "https://example.test/up", auth_value: "token" },
    doc("fatturaPa"),
    counting,
  );
  assertEquals(generic.status, "accepted");
  assertEquals(sent, 1, "the generic upload is untouched by the retirement");
});

Deno.test("what the remaining providers require is unchanged", () => {
  assertEquals(withoutItaly.requiredFields("peppol"), [
    "base_url",
    "api_key",
    "legal_entity_id",
  ]);
  assertEquals(withoutItaly.acceptedFormats("pl_ksef"), ["ksefFa3"]);
});
