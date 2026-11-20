// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3932 -- the Verifactu connector against a fake AEAT: what it sends, with
// which client certificate, and how the answer becomes an outcome. The
// answers are written from the response schema (not observed from the AEAT);
// the real handshake is NOT RUN here.
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  AEAT,
  ES_REFUSALS,
  esVerifactuConnector,
  type MakeClient,
  submitEsVerifactu,
} from "./connectors/es_verifactu.ts";
import type { ConnectorDocument } from "./connectors/common.ts";

const CERT = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----";
const KEY =
  "-----BEGIN PRIVATE KEY-----\nSECRETKEYMATERIAL\n-----END PRIVATE KEY-----";
const cfg = {
  base_url: AEAT.sandboxUrl,
  client_certificate: CERT,
  private_key: KEY,
};
const doc = (): ConnectorDocument & { dispatched: number } => {
  const d = {
    fileName: "TEST-1.xml",
    mimeType: "application/xml",
    bytes: new TextEncoder().encode("<soapenv:Envelope/>"),
    format: "verifactu",
    dispatched: 0,
    onDispatch() {
      d.dispatched++;
    },
  };
  return d as ConnectorDocument & { dispatched: number };
};
const line = (state: string, text = "") =>
  `<tikR:RespuestaLinea><tikR:EstadoRegistro>${state}</tikR:EstadoRegistro>` +
  (text
    ? `<tikR:DescripcionErrorRegistro>${text}</tikR:DescripcionErrorRegistro>`
    : "") +
  `</tikR:RespuestaLinea>`;
const answer = (state: string, lines: string) =>
  `<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Body>` +
  `<tikR:RespuestaRegFactuSistemaFacturacion xmlns:tikR="urn:r"><tikR:CSV>CSV-9</tikR:CSV>` +
  `<tikR:EstadoEnvio>${state}</tikR:EstadoEnvio>${lines}` +
  `</tikR:RespuestaRegFactuSistemaFacturacion></env:Body></env:Envelope>`;

function rig(
  respond: () => Response | Promise<Response> = () =>
    new Response(answer("Correcto", line("Correcto"))),
) {
  const sent: { url: string; init: RequestInit & { client?: unknown } }[] = [];
  const made: { cert: string; key: string; closed: boolean }[] = [];
  const makeClient: MakeClient = (cert, key) => {
    const c = { cert, key, closed: false };
    made.push(c);
    return { close: () => (c.closed = true) } as unknown as Deno.HttpClient;
  };
  const fetchImpl = ((url: string, init: RequestInit) => {
    sent.push({ url: String(url), init });
    return Promise.resolve(respond());
  }) as unknown as typeof fetch;
  return { sent, made, makeClient, fetchImpl };
}

Deno.test("#3932 the record goes to the AEAT sandbox as SOAP, behind the business's certificate, and the client is closed", async () => {
  const r = rig();
  const d = doc();
  const out = await submitEsVerifactu(cfg, d, r.fetchImpl, r.makeClient);
  assertEquals(r.sent.length, 1);
  assertEquals(r.sent[0].url, AEAT.sandboxUrl);
  assertEquals(r.sent[0].init.method, "POST");
  assertEquals(
    new Headers(r.sent[0].init.headers).get("content-type"),
    AEAT.contentType,
  );
  assert(r.sent[0].init.client !== undefined);
  assertEquals(r.sent[0].init.redirect, "manual");
  assertEquals([r.made[0].cert, r.made[0].key], [CERT, KEY]);
  assertEquals(r.made[0].closed, true);
  assertEquals(d.dispatched, 1);
  assertEquals([out.status, out.verdict, out.pending], [
    "accepted",
    "accepted",
    undefined,
  ]);
  assertEquals(out.externalId, "CSV-9");
  assertEquals((out.receipt as { csv: string }).csv, "CSV-9");
});

Deno.test("#3932 a record the AEAT refused is an accepted upload with a refused document", async () => {
  const r = rig(() =>
    new Response(answer("Incorrecto", line("Incorrecto", "Valor incorrecto")))
  );
  const out = await submitEsVerifactu(cfg, doc(), r.fetchImpl, r.makeClient);
  assertEquals([out.status, out.verdict], ["accepted", "rejected"]);
  assertEquals(out.detail, "Valor incorrecto");
});

Deno.test("#3932 a record kept with errors, or an answer of another shape, decides nothing", async () => {
  for (
    const body of [
      answer("ParcialmenteCorrecto", line("AceptadoConErrores", "x")),
      "<html>maintenance</html>",
    ]
  ) {
    const r = rig(() => new Response(body));
    const out = await submitEsVerifactu(cfg, doc(), r.fetchImpl, r.makeClient);
    assertEquals([out.status, out.pending, out.verdict], [
      "accepted",
      true,
      undefined,
    ]);
  }
});

Deno.test("#3932 an address that is not the AEAT's gets neither the request nor the certificate", async () => {
  for (
    const base_url of [
      "https://evil.example/ws",
      "not a url",
      "http://prewww1.aeat.es/x",
    ]
  ) {
    const r = rig();
    const d = doc();
    const out = await submitEsVerifactu(
      { ...cfg, base_url },
      d,
      r.fetchImpl,
      r.makeClient,
    );
    assertEquals([out.status, out.detail], ["failed", ES_REFUSALS.host]);
    assertEquals([r.sent.length, r.made.length, d.dispatched], [0, 0, 0]);
  }
});

Deno.test("#3932 a certificate or key that is not PEM, or that Deno refuses, sends nothing and says a fixed key", async () => {
  const bad = [
    { ...cfg, private_key: "" },
    { ...cfg, client_certificate: "abc" },
    { ...cfg, private_key: CERT },
  ];
  for (const c of bad) {
    const r = rig();
    const out = await submitEsVerifactu(c, doc(), r.fetchImpl, r.makeClient);
    assertEquals([out.status, out.detail], ["failed", ES_REFUSALS.certificate]);
    assertEquals([r.sent.length, r.made.length], [0, 0]);
  }
  const r = rig();
  const out = await submitEsVerifactu(cfg, doc(), r.fetchImpl, () => {
    throw new Error(`bad key ${KEY}`);
  });
  assertEquals([out.status, out.detail], ["failed", ES_REFUSALS.certificate]);
  assertEquals(r.sent.length, 0);
});

Deno.test("#3932 a typed \\n in a stored PEM is a line break", async () => {
  const r = rig();
  await submitEsVerifactu(
    {
      ...cfg,
      client_certificate: CERT.replace(/\n/g, "\\n"),
      private_key: KEY.replace(/\n/g, "\\n"),
    },
    doc(),
    r.fetchImpl,
    r.makeClient,
  );
  assertEquals([r.made[0].cert, r.made[0].key], [CERT, KEY]);
});

Deno.test("#3932 a refusal and a thrown fetch close the client and never carry the key", async () => {
  const refused = rig(() => new Response("no", { status: 403 }));
  const a = await submitEsVerifactu(
    cfg,
    doc(),
    refused.fetchImpl,
    refused.makeClient,
  );
  assertEquals([a.status, a.httpStatus], ["rejected", 403]);
  assertEquals(refused.made[0].closed, true);
  const thrown = rig(() => {
    throw new Error("handshake failed");
  });
  const b = await submitEsVerifactu(
    cfg,
    doc(),
    thrown.fetchImpl,
    thrown.makeClient,
  );
  assertEquals(b.status, "failed");
  assertEquals(thrown.made[0].closed, true);
  for (const out of [a, b]) {
    assert(!JSON.stringify(out).includes("SECRETKEYMATERIAL"));
  }
});

Deno.test("#3932 the connector is a test channel with its sandbox and no status query", () => {
  assertEquals(esVerifactuConnector.id, "es_verifactu");
  assertEquals(esVerifactuConnector.requiredFields, [
    "base_url",
    "client_certificate",
    "private_key",
  ]);
  assertEquals(esVerifactuConnector.acceptedFormats, ["verifactu"]);
  assertEquals(esVerifactuConnector.testDocument, true);
  assertEquals(esVerifactuConnector.status, undefined);
  assertEquals(esVerifactuConnector.sandbox, { base_url: AEAT.sandboxUrl });
});

Deno.test("#3932 a runtime that cannot present a client certificate sends nothing and says so", async () => {
  const r = rig();
  const d = doc();
  const out = await submitEsVerifactu(cfg, d, r.fetchImpl, () => {
    throw new Error(ES_REFUSALS.mtls);
  });
  assertEquals([out.status, out.detail], ["failed", ES_REFUSALS.mtls]);
  assertEquals([r.sent.length, d.dispatched], [0, 0]);
  const before = Deno.createHttpClient;
  // deno-lint-ignore no-explicit-any
  (Deno as any).createHttpClient = undefined;
  try {
    const none = await submitEsVerifactu(cfg, doc(), r.fetchImpl);
    assertEquals([none.status, none.detail], ["failed", ES_REFUSALS.mtls]);
    assertEquals(r.sent.length, 0);
  } finally {
    Deno.createHttpClient = before;
  }
});

Deno.test("#3932 the owner reads the fixed keys of a certificate failure, never more", async () => {
  const { clientDetail } = await import("./connectors/safe_fetch.ts");
  assertEquals(clientDetail("failed", ES_REFUSALS.certificate), "certificate_unreadable");
  assertEquals(clientDetail("failed", ES_REFUSALS.mtls), "mtls_unavailable");
  assertEquals(clientDetail("failed", "anything else"), "provider_unreachable");
});
