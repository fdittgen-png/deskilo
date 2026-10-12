// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — the connectors against mocked providers: the exact requests
// each makes, how each answer becomes a logged outcome, and the KSeF
// cryptography end to end (the test plays the ministry and decrypts what
// the connector sent). No request leaves the test.

import { assert, assertEquals, assertMatch } from "jsr:@std/assert@1";
import {
  acceptedFormats,
  PROVIDERS,
  requiredFields,
  SANDBOX,
  status,
  submit,
} from "./connectors.ts";
import { fromBase64, toBase64 } from "./connectors/common.ts";
import { spkiOfCertificate } from "./connectors/der.ts";
import { KSEF, submitPlKsef } from "./connectors/pl_ksef.ts";
import { xmlAttribute } from "./connectors/ro_efactura.ts";

interface Call {
  method: string;
  url: string;
  headers: Record<string, string>;
  body: unknown;
}

/** A fetch that answers with [respond] and records every call. */
function mock(respond: (call: Call, index: number) => Response) {
  const calls: Call[] = [];
  const fetchImpl = (input: RequestInfo | URL, init?: RequestInit) => {
    const call: Call = {
      method: init?.method ?? "GET",
      url: String(input),
      headers: Object.fromEntries(new Headers(init?.headers).entries()),
      body: init?.body,
    };
    calls.push(call);
    return Promise.resolve(respond(call, calls.length - 1));
  };
  return { calls, fetchImpl: fetchImpl as typeof fetch };
}

const ok = (body: unknown, status = 200) =>
  new Response(typeof body === "string" ? body : JSON.stringify(body), {
    status,
  });

const throwing =
  (() =>
    Promise.reject(new TypeError("network down"))) as unknown as typeof fetch;

const xml = (format: string, text = "<Invoice/>") => ({
  fileName: "F-1.xml",
  mimeType: "application/xml",
  bytes: new TextEncoder().encode(text),
  format,
  number: "F-1",
  receiver: { scheme: "0208", id: "0202239951" },
});

Deno.test("every provider names its fields and a sandbox entry", () => {
  for (const p of PROVIDERS) {
    assert(requiredFields(p).length > 0, p);
    assert(p in SANDBOX, p);
  }
  assertEquals(requiredFields("ro_efactura"), [
    "base_url",
    "cif",
    "access_token",
  ]);
  assertEquals(acceptedFormats("it_sdi"), ["fatturaPa"]);
});

Deno.test("a format the provider does not take is refused before any call", async () => {
  for (
    const [provider, format] of [
      ["peppol", "fatturaPa"],
      ["it_sdi", "peppolBis"],
      ["pl_ksef", "ciusRo"],
      ["ro_efactura", "ksefFa3"],
      ["fr_pa", "fatturaPa"],
    ]
  ) {
    const { calls, fetchImpl } = mock(() => ok({}));
    const out = await submit(provider, {}, xml(format), fetchImpl);
    assertEquals(out.status, "rejected", provider);
    assertMatch(out.detail, /does not accept/);
    assertEquals(calls.length, 0, provider);
  }
});

Deno.test("generic: multipart upload, the id read from the answer", async () => {
  const { calls, fetchImpl } = mock(() => ok({ documentId: "D-9" }));
  const out = await submit(
    "generic",
    { endpoint: "https://pa.test/upload", auth_value: "Bearer t" },
    { ...xml("facturX"), mimeType: "application/pdf", fileName: "F-1.pdf" },
    fetchImpl,
  );
  assertEquals(out.status, "accepted");
  assertEquals(out.externalId, "D-9");
  assertEquals(calls[0].method, "POST");
  assertEquals(calls[0].url, "https://pa.test/upload");
  assertEquals(calls[0].headers.authorization, "Bearer t");
  const form = calls[0].body as FormData;
  assertEquals((form.get("file") as File).name, "F-1.pdf");
});

Deno.test("peppol: the UBL as raw document data, routed by BT-49", async () => {
  const { calls, fetchImpl } = mock(() => ok({ guid: "g-1" }));
  const doc = xml("peppolBis");
  const out = await submit(
    "peppol",
    { base_url: "https://ap.test/", api_key: "k", legal_entity_id: "42" },
    doc,
    fetchImpl,
  );
  assertEquals(out.status, "accepted");
  assertEquals(out.externalId, "g-1");
  assertEquals(calls[0].url, "https://ap.test/api/v2/document_submissions");
  assertEquals(calls[0].headers.authorization, "Bearer k");
  const body = JSON.parse(calls[0].body as string);
  assertEquals(body.legalEntityId, 42);
  assertEquals(body.routing.eIdentifiers, [{
    scheme: "BE:EN",
    id: "0202239951",
  }]);
  assertEquals(body.document.documentType, "invoice");
  assertEquals(fromBase64(body.document.rawDocumentData.document), doc.bytes);
  assertEquals(body.document.rawDocumentData.parseStrategy, "ubl");

  const evidence = mock(() => ok({ receiver: "AS4 receipt" }));
  const read = await status(
    "peppol",
    { base_url: "https://ap.test", api_key: "k" },
    "g-1",
    evidence.fetchImpl,
  );
  assertEquals(
    evidence.calls[0].url,
    "https://ap.test/api/v2/document_submissions/g-1/evidence/sending",
  );
  assertEquals(
    (read.receipt.evidence as Record<string, unknown>).receiver,
    "AS4 receipt",
  );
});

Deno.test("peppol: no electronic address, nothing to route to", async () => {
  const { calls, fetchImpl } = mock(() => ok({}));
  const out = await submit("peppol", { base_url: "https://ap.test" }, {
    ...xml("peppolBis"),
    receiver: undefined,
  }, fetchImpl);
  assertEquals(out.status, "rejected");
  assertEquals(calls.length, 0);
});

Deno.test("fr_pa: client-credentials token, then the AFNOR flow", async () => {
  const { calls, fetchImpl } = mock((call) =>
    call.url.endsWith("/token")
      ? ok({ access_token: "at" })
      : ok({ flowId: "FL-7" })
  );
  const cfg = {
    base_url: "https://pa.test/api",
    token_url: "https://pa.test/token",
    client_id: "c",
    client_secret: "s",
  };
  const out = await submit("fr_pa", cfg, xml("en16931Cii"), fetchImpl);
  assertEquals(out.status, "accepted");
  assertEquals(out.externalId, "FL-7");
  assertEquals(
    (calls[0].body as URLSearchParams).get("grant_type"),
    "client_credentials",
  );
  assertEquals(calls[1].url, "https://pa.test/api/v1/flows");
  assertEquals(calls[1].headers.authorization, "Bearer at");
  const form = calls[1].body as FormData;
  const info = JSON.parse(await (form.get("flowInfo") as Blob).text());
  assertEquals(info, {
    trackingId: "F-1",
    name: "F-1.xml",
    processingRule: "B2B",
    flowSyntax: "CII",
  });
  assert(form.get("file") instanceof Blob);

  const read = mock((call) =>
    call.url.endsWith("/token")
      ? ok({ access_token: "at" })
      : ok({ flowStatus: "Rejected" })
  );
  const back = await status("fr_pa", cfg, "FL-7", read.fetchImpl);
  assertEquals(read.calls[1].url, "https://pa.test/api/v1/flows/FL-7");
  assertEquals(back.receipt.flowStatus, "Rejected");
});

Deno.test("fr_pa: a refused token is a refusal, not a send", async () => {
  const { calls, fetchImpl } = mock(() => ok("bad client", 401));
  const out = await submit(
    "fr_pa",
    { token_url: "https://pa.test/token", base_url: "x" },
    xml("en16931Cii"),
    fetchImpl,
  );
  assertEquals(out.status, "rejected");
  assertEquals(out.detail, "401 bad client");
  assertEquals(calls.length, 1);
});

Deno.test("it_sdi: login, the FatturaPA as XML, the SdI notifications", async () => {
  const cfg = {
    base_url: "https://sdi.test",
    login_url: "https://login.test/login",
    username: "u@x.it",
    password: "p",
  };
  const { calls, fetchImpl } = mock((call) =>
    call.url.endsWith("/login")
      ? ok({ token: "jwt" })
      : ok({ uuid: "u-1" }, 202)
  );
  const doc = xml("fatturaPa");
  const out = await submit("it_sdi", cfg, doc, fetchImpl);
  assertEquals(out.externalId, "u-1");
  assertEquals(JSON.parse(calls[0].body as string), {
    email: "u@x.it",
    password: "p",
  });
  assertEquals(calls[1].url, "https://sdi.test/invoices");
  assertEquals(calls[1].headers["content-type"], "application/xml");
  assertEquals(calls[1].headers.authorization, "Bearer jwt");
  assertEquals(calls[1].body, doc.bytes);

  const scarto = mock((call) =>
    call.url.endsWith("/login")
      ? ok({ token: "jwt" })
      : call.url.endsWith("/notifications")
      ? ok([{ type: "NS", message: "00404 duplicate" }])
      : ok({ marking: "rejected" })
  );
  const back = await status("it_sdi", cfg, "u-1", scarto.fetchImpl);
  assertEquals(back.status, "rejected");
  assertEquals(
    scarto.calls[2].url,
    "https://sdi.test/invoices/u-1/notifications",
  );

  const consegna = mock((call) =>
    call.url.endsWith("/login")
      ? ok({ token: "jwt" })
      : call.url.endsWith("/notifications")
      ? ok([{ type: "RC" }])
      : ok({ marking: "delivered" })
  );
  assertEquals(
    (await status("it_sdi", cfg, "u-1", consegna.fetchImpl)).status,
    "accepted",
  );
});

Deno.test("ro_efactura: upload by CIF, index_incarcare, stareMesaj", async () => {
  const cfg = {
    base_url: "https://anaf.test/FCTEL/rest",
    cif: "1234567",
    access_token: "a",
  };
  const answer =
    '<?xml version="1.0"?><header xmlns="mfp:anaf:dgti:spv:respUploadFisier:v1" dateResponse="202610111200" ExecutionStatus="0" index_incarcare="3828"/>';
  const { calls, fetchImpl } = mock(() => ok(answer));
  const out = await submit("ro_efactura", cfg, xml("ciusRo"), fetchImpl);
  assertEquals(out.externalId, "3828");
  assertEquals(
    calls[0].url,
    "https://anaf.test/FCTEL/rest/upload?standard=UBL&cif=1234567",
  );
  assertEquals(calls[0].headers.authorization, "Bearer a");

  const credit = mock(() => ok(answer));
  await submit(
    "ro_efactura",
    cfg,
    xml("ciusRo", '<?xml version="1.0"?><CreditNote xmlns="x"/>'),
    credit.fetchImpl,
  );
  assertMatch(credit.calls[0].url, /standard=CN/);

  const refusedUpload = mock(() =>
    ok(
      '<header ExecutionStatus="1"><Errors errorMessage="Fisierul nu respecta CIUS-RO"/></header>',
    )
  );
  const no = await submit(
    "ro_efactura",
    cfg,
    xml("ciusRo"),
    refusedUpload.fetchImpl,
  );
  assertEquals(no.status, "rejected");
  assertEquals(no.detail, "Fisierul nu respecta CIUS-RO");

  const done = mock(() => ok('<header stare="ok" id_descarcare="991"/>'));
  const back = await status("ro_efactura", cfg, "3828", done.fetchImpl);
  assertEquals(
    done.calls[0].url,
    "https://anaf.test/FCTEL/rest/stareMesaj?id_incarcare=3828",
  );
  assertEquals(back.receipt.id_descarcare, "991");
  const nok = mock(() => ok('<header stare="nok" id_descarcare="992"/>'));
  assertEquals(
    (await status("ro_efactura", cfg, "3828", nok.fetchImpl)).status,
    "rejected",
  );
  assertEquals(
    xmlAttribute('<a:header x="1" stare="in prelucrare"/>', "header", "stare"),
    "in prelucrare",
  );
});

Deno.test("every connector: a non-2xx answer is a refusal, a thrown fetch a failure", async () => {
  const cfgs: Record<string, Record<string, string>> = {
    generic: { endpoint: "https://x.test", auth_value: "t" },
    peppol: { base_url: "https://x.test", api_key: "k", legal_entity_id: "1" },
    it_sdi: { base_url: "https://x.test", login_url: "https://x.test/login" },
    ro_efactura: { base_url: "https://x.test", cif: "1", access_token: "a" },
  };
  const formats: Record<string, string> = {
    generic: "facturX",
    peppol: "peppolBis",
    it_sdi: "fatturaPa",
    ro_efactura: "ciusRo",
  };
  for (const [provider, cfg] of Object.entries(cfgs)) {
    const { fetchImpl } = mock(() => ok("x".repeat(900), 400));
    const no = await submit(provider, cfg, xml(formats[provider]), fetchImpl);
    assertEquals(no.status, "rejected", provider);
    assertEquals(no.detail.length, 500, provider);
    const down = await submit(provider, cfg, xml(formats[provider]), throwing);
    assertEquals(down.status, "failed", provider);
    assertMatch(down.detail, /network down/);
  }
});

// ── KSeF: the test plays the ministry ───────────────────────────────

function der(tag: number, content: Uint8Array): Uint8Array {
  const len = content.length;
  const head = len < 0x80
    ? [tag, len]
    : len < 0x100
    ? [tag, 0x81, len]
    : [tag, 0x82, len >> 8, len & 0xff];
  return new Uint8Array([...head, ...content]);
}
const seq = (...parts: Uint8Array[]) =>
  der(0x30, new Uint8Array(parts.flatMap((p) => [...p])));

/** A certificate-shaped DER around [spki]: version, serial, the empty
 * names and validity a reader must skip, then the key. */
function certificateFor(spki: Uint8Array): Uint8Array {
  const tbs = seq(
    der(0xa0, der(0x02, new Uint8Array([2]))),
    der(0x02, new Uint8Array([1])),
    seq(),
    seq(),
    seq(),
    seq(),
    spki,
  );
  return seq(tbs, seq(), der(0x03, new Uint8Array([0])));
}

Deno.test("the SPKI comes out of a certificate byte for byte", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSA-OAEP",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["encrypt", "decrypt"],
  );
  const spki = new Uint8Array(
    await crypto.subtle.exportKey("spki", pair.publicKey),
  );
  assertEquals(spkiOfCertificate(certificateFor(spki)), spki);
});

Deno.test("pl_ksef: token auth, session, encrypted invoice — all decryptable by the ministry", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSA-OAEP",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["encrypt", "decrypt"],
  );
  const spki = new Uint8Array(
    await crypto.subtle.exportKey("spki", pair.publicKey),
  );
  const cert = toBase64(certificateFor(spki));
  const decrypt = async (b64: string) =>
    new Uint8Array(
      await crypto.subtle.decrypt(
        { name: "RSA-OAEP" },
        pair.privateKey,
        fromBase64(b64),
      ),
    );
  let authPolls = 0;
  const { calls, fetchImpl } = mock((call) => {
    const path = call.url.replace("https://ksef.test/api/v2/", "");
    if (path === KSEF.certificates) {
      return ok([
        { certificate: cert, usage: [KSEF.usageToken] },
        { certificate: cert, usage: [KSEF.usageSymmetric] },
      ]);
    }
    if (path === KSEF.challenge) {
      return ok({ challenge: "CH-1", timestampMs: 1760000000000 });
    }
    if (path === KSEF.tokenAuth) {
      return ok({
        referenceNumber: "AUTH-1",
        authenticationToken: { token: "auth-jwt" },
      });
    }
    if (path === KSEF.authStatus("AUTH-1")) {
      authPolls++;
      return ok({
        status: { code: authPolls < 2 ? KSEF.authPending : KSEF.authDone },
      });
    }
    if (path === KSEF.redeem) {
      return ok({ accessToken: { token: "access-jwt" } });
    }
    if (path === KSEF.openSession) return ok({ referenceNumber: "S-1" });
    if (path === KSEF.sendInvoice("S-1")) return ok({ referenceNumber: "I-1" });
    if (path === KSEF.closeSession("S-1")) {
      return new Response(null, { status: 204 });
    }
    return ok("unexpected", 500);
  });
  const doc = xml("ksefFa3", "<Faktura>zażółć</Faktura>");
  const out = await submitPlKsef(
    {
      base_url: "https://ksef.test/api/v2",
      nip: "5260001246",
      ksef_token: "TOKEN-XYZ",
    },
    doc,
    fetchImpl,
    () => Promise.resolve(),
  );
  assertEquals(out.status, "accepted", out.detail);
  assertEquals(out.externalId, "S-1/I-1");
  assertEquals(authPolls, 2);

  const auth = JSON.parse(
    calls.find((c) => c.url.endsWith(KSEF.tokenAuth))!.body as string,
  );
  assertEquals(auth.challenge, "CH-1");
  assertEquals(auth.contextIdentifier, { type: "Nip", value: "5260001246" });
  assertEquals(
    new TextDecoder().decode(await decrypt(auth.encryptedToken)),
    "TOKEN-XYZ|1760000000000",
  );

  const redeem = calls.find((c) => c.url.endsWith(KSEF.redeem))!;
  assertEquals(redeem.headers.authorization, "Bearer auth-jwt");
  const open = calls.find((c) => c.url.endsWith(KSEF.openSession))!;
  assertEquals(open.headers.authorization, "Bearer access-jwt");
  const session = JSON.parse(open.body as string);
  assertEquals(session.formCode, KSEF.formCode);
  const aesKey = await decrypt(session.encryption.encryptedSymmetricKey);
  assertEquals(aesKey.length, 32);

  const sent = JSON.parse(
    calls.find((c) => c.url.endsWith(KSEF.sendInvoice("S-1")))!.body as string,
  );
  const key = await crypto.subtle.importKey(
    "raw",
    aesKey,
    { name: "AES-CBC" },
    false,
    ["decrypt"],
  );
  const plain = new Uint8Array(
    await crypto.subtle.decrypt(
      {
        name: "AES-CBC",
        iv: fromBase64(session.encryption.initializationVector),
      },
      key,
      fromBase64(sent.encryptedInvoiceContent),
    ),
  );
  assertEquals(plain, doc.bytes);
  assertEquals(sent.invoiceSize, doc.bytes.length);
  assertEquals(
    sent.encryptedInvoiceSize,
    fromBase64(sent.encryptedInvoiceContent).length,
  );
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", doc.bytes),
  );
  assertEquals(sent.invoiceHash, toBase64(digest));
  assert(calls.some((c) => c.url.endsWith(KSEF.closeSession("S-1"))));
});

Deno.test("pl_ksef: a refused authentication sends nothing", async () => {
  const { calls, fetchImpl } = mock((call) =>
    call.url.endsWith(KSEF.certificates) ? ok("down", 503) : ok({})
  );
  const out = await submit(
    "pl_ksef",
    { base_url: "https://ksef.test/api/v2", nip: "1", ksef_token: "t" },
    xml("ksefFa3"),
    fetchImpl,
  );
  assertEquals(out.status, "rejected");
  assertEquals(calls.length, 1);
});
