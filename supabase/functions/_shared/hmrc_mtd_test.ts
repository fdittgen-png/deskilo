// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — HMRC MTD VAT against recorded responses (shapes taken from HMRC's
// VAT (MTD) API documentation; not yet replayed against a registered
// sandbox application). No request leaves a test run.
import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import { exchangeCode, isFailure, refreshTokens } from "./accounting_oauth.ts";
import {
  fraudHeaders,
  FraudHeadersMissing,
  HmrcInputError,
  hmrcTarget,
  obligationFor,
  openObligations,
  returnBody,
  submitReturn,
  validateHeaders,
} from "./hmrc_mtd.ts";
import type { ClientValues, NineBoxes, VendorValues } from "./hmrc_mtd.ts";

const BASE = "https://test-api.service.hmrc.gov.uk";
const SIGN_IN = "https://test-www.tax.service.gov.uk";

const BOXES: NineBoxes = {
  vatDueSales: 105.5,
  vatDueAcquisitions: 4.25,
  totalVatDue: 109.75,
  vatReclaimedCurrPeriod: 40.1,
  netVatDue: 69.65,
  totalValueSalesExVAT: 500,
  totalValuePurchasesExVAT: 240,
  totalValueGoodsSuppliedExVAT: 0,
  totalAcquisitionsExVAT: 20,
};

const CLIENT: ClientValues = {
  browserJsUserAgent: "Mozilla/5.0 (Macintosh)",
  deviceId: "7e3f1a52-0000-4000-8000-123456789abc",
  userId: "user 1",
  timezone: "UTC+01:00",
  screens: "width=1920&height=1080&scaling-factor=1&colour-depth=24",
  windowSize: "width=1256&height=803",
  doNotTrack: false,
  publicIp: "198.51.100.7",
  publicIpTimestamp: "2026-11-01T10:00:00.123Z",
  publicPort: "49152",
};
const VENDOR: VendorValues = {
  productName: "Deskilo Cowork",
  version: "deskilo=1.4.0",
  publicIp: "203.0.113.9",
  forwardedFor: "198.51.100.7",
};

type Seen = { url: string; init: RequestInit };
function play(status: number, body: unknown, seen: Seen[] = []): typeof fetch {
  return (url, init) => {
    seen.push({ url: String(url), init: init ?? {} });
    return Promise.resolve(
      new Response(JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
      }),
    );
  };
}

Deno.test("the OAuth target is the installation's base URL with the two scopes", () => {
  const t = hmrcTarget(`${BASE}/`, `${SIGN_IN}/`);
  assertEquals(t.authorizeUrl, `${SIGN_IN}/oauth/authorize`);
  assertEquals(t.tokenUrl, `${BASE}/oauth/token`);
  assertEquals(t.scopes, ["read:vat", "write:vat"]);
  assertEquals(t.clientAuth, "body");
});

Deno.test("token exchange and refresh send the client in the server-to-server form body", async () => {
  const seen: Seen[] = [];
  const token = await exchangeCode(
    play(200, {
      access_token: "at",
      refresh_token: "rt",
      expires_in: 14400,
      scope: "read:vat write:vat",
    }, seen),
    hmrcTarget(BASE, SIGN_IN),
    { clientId: "cid", clientSecret: "sec" },
    "the-code",
    "https://app.example/cb",
    new Date("2026-11-01T10:00:00Z"),
  );
  if (isFailure(token)) throw new Error("exchange failed");
  assertEquals(token.accessToken, "at");
  const sent = new URLSearchParams(String(seen[0].init.body));
  assertEquals(sent.get("client_secret"), "sec");
  assertEquals(sent.get("client_id"), "cid");
  assertEquals(
    (seen[0].init.headers as Record<string, string>).authorization,
    undefined,
  );
  const refused = await refreshTokens(
    play(400, { error: "invalid_grant" }),
    hmrcTarget(BASE, SIGN_IN),
    { clientId: "cid", clientSecret: "sec" },
    "rt",
    new Date("2026-11-01T10:00:00Z"),
  );
  assertEquals(isFailure(refused) && refused.reason, "refused");
});

Deno.test("the body is the nine boxes exactly, finalised", () => {
  const body = returnBody("18A1", BOXES);
  assertEquals(body, { periodKey: "18A1", ...BOXES, finalised: true });
});

Deno.test("HMRC's arithmetic is checked before a round trip", () => {
  assertThrows(
    () => returnBody("18A1", { ...BOXES, totalVatDue: 109.7 }),
    HmrcInputError,
  );
  assertThrows(
    () => returnBody("18A1", { ...BOXES, netVatDue: 70 }),
    HmrcInputError,
  );
  assertThrows(
    () => returnBody("18A1", { ...BOXES, totalValueSalesExVAT: 500.5 }),
    HmrcInputError,
  );
  assertThrows(
    () =>
      returnBody("18A1", {
        ...BOXES,
        vatDueSales: 105.555,
        totalVatDue: 109.805,
      }),
    HmrcInputError,
  );
  assertThrows(() => returnBody("18", BOXES), HmrcInputError);
});

Deno.test("a refund return: the net is the unsigned difference", () => {
  const refund = { ...BOXES, vatReclaimedCurrPeriod: 200, netVatDue: 90.25 };
  assertEquals(returnBody("18A1", refund).netVatDue, 90.25);
});

Deno.test("the fraud headers of WEB_APP_VIA_SERVER, encoded, no invented values", () => {
  const h = fraudHeaders(CLIENT, VENDOR);
  assertEquals(h["Gov-Client-Connection-Method"], "WEB_APP_VIA_SERVER");
  assertEquals(h["Gov-Client-User-IDs"], "deskilo=user%201");
  assertEquals(h["Gov-Vendor-Product-Name"], "Deskilo%20Cowork");
  assertEquals(h["Gov-Vendor-Forwarded"], "by=203.0.113.9&for=198.51.100.7");
  assertEquals(h["Gov-Client-Browser-Do-Not-Track"], "false");
  assertEquals(
    "Gov-Client-Multi-Factor" in h,
    false,
    "no second factor, no header",
  );
  assertEquals("Gov-Vendor-License-IDs" in h, false);
  assertEquals(
    fraudHeaders({
      ...CLIENT,
      multiFactor: "type=TOTP&timestamp=x&unique-reference=y",
    }, VENDOR)["Gov-Client-Multi-Factor"],
    "type=TOTP&timestamp=x&unique-reference=y",
  );
});

Deno.test("a missing client value names the header and sends nothing", () => {
  const e = assertThrows(
    () => fraudHeaders({ ...CLIENT, deviceId: "", screens: "  " }, VENDOR),
    FraudHeadersMissing,
  );
  assertEquals(e.missing, ["Gov-Client-Device-ID", "Gov-Client-Screens"]);
});

Deno.test("obligations: the open one matches the prepared period", async () => {
  const seen: Seen[] = [];
  const r = await openObligations(
    play(200, {
      obligations: [
        {
          start: "2026-01-01",
          end: "2026-03-31",
          due: "2026-05-07",
          status: "O",
          periodKey: "26A1",
        },
      ],
    }, seen),
    BASE,
    "123456789",
    "at",
    fraudHeaders(CLIENT, VENDOR),
    "2026-01-01",
    "2026-12-31",
  );
  if (!r.ok) throw new Error("obligations failed");
  assertEquals(
    seen[0].url,
    `${BASE}/organisations/vat/123456789/obligations?from=2026-01-01&to=2026-12-31&status=O`,
  );
  const headers = seen[0].init.headers as Record<string, string>;
  assertEquals(headers.accept, "application/vnd.hmrc.1.0+json");
  assertEquals(headers.authorization, "Bearer at");
  assertEquals(headers["Gov-Client-Connection-Method"], "WEB_APP_VIA_SERVER");
  assertEquals(
    obligationFor(r.obligations, "2026-01-01", "2026-03-31")?.periodKey,
    "26A1",
  );
  assertEquals(obligationFor(r.obligations, "2026-04-01", "2026-06-30"), null);
});

Deno.test("submission: the receipt is the form bundle number", async () => {
  const seen: Seen[] = [];
  const r = await submitReturn(
    play(201, {
      processingDate: "2026-04-12T10:20:30.000Z",
      formBundleNumber: "256660290587",
      chargeRefNumber: "aaa",
    }, seen),
    BASE,
    "123456789",
    "at",
    fraudHeaders(CLIENT, VENDOR),
    "26A1",
    BOXES,
  );
  if (!r.ok) throw new Error("submission failed");
  assertEquals(r.receipt.formBundleNumber, "256660290587");
  assertEquals(r.receipt.chargeRefNumber, "aaa");
  assertEquals(seen[0].url, `${BASE}/organisations/vat/123456789/returns`);
  assertEquals(seen[0].init.method, "POST");
  assertEquals(JSON.parse(String(seen[0].init.body)).finalised, true);
});

Deno.test("HMRC's refusals are told apart and never carry a token", async () => {
  const call = (status: number, code: string) =>
    submitReturn(
      play(status, { code }),
      BASE,
      "123456789",
      "at",
      fraudHeaders(CLIENT, VENDOR),
      "26A1",
      BOXES,
    );
  assertEquals(await call(401, "INVALID_CREDENTIALS"), {
    ok: false,
    reason: "token",
    status: 401,
    code: "INVALID_CREDENTIALS",
  });
  assertEquals(
    (await call(403, "NOT_SIGNED_UP_TO_MTD") as { reason: string }).reason,
    "not_authorised",
  );
  assertEquals(
    (await call(409, "DUPLICATE_SUBMISSION") as { reason: string }).reason,
    "already_submitted",
  );
  assertEquals(
    (await call(422, "TAX_PERIOD_NOT_ENDED") as { reason: string }).reason,
    "refused",
  );
  assertEquals(
    (await call(400, "INVALID_REQUEST") as { reason: string }).reason,
    "refused",
  );
  assertEquals(
    (await call(429, "MESSAGE_THROTTLED_OUT") as { reason: string }).reason,
    "busy",
  );
  assertEquals(
    (await call(503, "SERVER_ERROR") as { reason: string }).reason,
    "unreachable",
  );
});

Deno.test("refusals are read by HMRC's documented body code, not by the status alone", async () => {
  const call = (status: number, body: unknown) =>
    submitReturn(
      play(status, body),
      BASE,
      "123456789",
      "at",
      fraudHeaders(CLIENT, VENDOR),
      "26A1",
      BOXES,
    );
  const reason = async (status: number, body: unknown) =>
    (await call(status, body) as { reason: string }).reason;
  // The public vat-api sends all three of these as 403.
  assertEquals(
    await reason(403, { code: "DUPLICATE_SUBMISSION" }),
    "already_submitted",
  );
  assertEquals(await reason(403, { code: "TAX_PERIOD_NOT_ENDED" }), "refused");
  assertEquals(
    await reason(403, { code: "CLIENT_OR_AGENT_NOT_AUTHORISED" }),
    "not_authorised",
  );
  assertEquals(
    await reason(403, { code: "NOT_SIGNED_UP_TO_MTD" }),
    "not_authorised",
  );
  // A business error carries its code one level down (bounded).
  assertEquals(
    await reason(403, {
      code: "BUSINESS_ERROR",
      errors: [{ code: "DUPLICATE_SUBMISSION" }],
    }),
    "already_submitted",
  );
  assertEquals(
    await reason(403, {
      code: "BUSINESS_ERROR",
      errors: [{ code: "TAX_PERIOD_NOT_ENDED" }],
    }),
    "refused",
  );
  // A status never invents a duplicate or an authorisation: unknown, missing or
  // malformed bodies are a plain refusal, and nothing is filed.
  assertEquals(await reason(409, { code: "SOMETHING_NEW" }), "refused");
  assertEquals(await reason(409, undefined), "refused");
  assertEquals(await reason(403, "not an object"), "refused");
  assertEquals(await reason(403, { code: 42 }), "refused");
  assertEquals(
    await reason(403, { code: "BUSINESS_ERROR", errors: "x" }),
    "refused",
  );
  // The code is bounded and the nested list is capped.
  const long = await call(403, { code: "X".repeat(500) });
  assertEquals(long.ok === false && long.code.length <= 60, true);
  // Whatever the code, a refusal never carries a receipt.
  assertEquals(
    (await call(403, { code: "DUPLICATE_SUBMISSION", formBundleNumber: "1" }))
      .ok,
    false,
  );
});

Deno.test("a success whose body is not an object is no receipt", async () => {
  for (const body of [null, "ok", [1]]) {
    const r = await submitReturn(
      play(201, body),
      BASE,
      "123456789",
      "at",
      fraudHeaders(CLIENT, VENDOR),
      "26A1",
      BOXES,
    );
    assertEquals(r.ok === false && r.code, "NO_RECEIPT");
  }
});

Deno.test("no network and no receipt are failures, not successes", async () => {
  const down: typeof fetch = () => Promise.reject(new Error("offline"));
  assertEquals(
    (await submitReturn(
      down,
      BASE,
      "123456789",
      "at",
      fraudHeaders(CLIENT, VENDOR),
      "26A1",
      BOXES,
    )).ok,
    false,
  );
  const empty = await submitReturn(
    play(201, {}),
    BASE,
    "123456789",
    "at",
    fraudHeaders(CLIENT, VENDOR),
    "26A1",
    BOXES,
  );
  assertEquals(empty.ok === false && empty.code, "NO_RECEIPT");
});

Deno.test("a VRN is nine digits", async () => {
  await assertRejects(
    () =>
      openObligations(
        play(200, {}),
        BASE,
        "12345",
        "at",
        {},
        "2026-01-01",
        "2026-12-31",
      ),
    HmrcInputError,
  );
});

Deno.test("header validation reports HMRC's findings", async () => {
  const bad = await validateHeaders(
    play(400, {
      code: "INVALID_HEADERS",
      message: "x",
      errors: [{ code: "INVALID_HEADER", headers: ["gov-client-device-id"] }],
    }),
    BASE,
    "at",
    fraudHeaders(CLIENT, VENDOR),
  );
  assertEquals(bad.ok && bad.errors.length, 1);
  const good = await validateHeaders(
    play(200, { code: "VALID_HEADERS" }),
    BASE,
    "at",
    fraudHeaders(CLIENT, VENDOR),
  );
  assertEquals(good.ok && good.code, "VALID_HEADERS");
});
