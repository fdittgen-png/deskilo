// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2377 — the adapter of the accounting target `bexio_api`: the bexio API
// 2.0, the accounting platform most Swiss SMEs and fiduciaries run. It is a
// [RemoteAdapter] of the delivery kit (`_shared/accounting_delivery.ts`):
// the kit stores the delivery and its idempotency key first, blocks a
// document whose mapping keys are not all mapped, reads an unknown outcome
// back before creating, and never creates twice. This module knows bexio:
//
//   * an invoice is a `kb_invoice` created with its legal number as
//     `document_nr`, the kit's idempotency key as `api_reference`, its
//     validity from the issue day to the due day, positions net with the
//     `tax_id` and `account_id` the connection maps, the customer the
//     contact the connection maps, then issued (`/issue`): bexio never
//     renumbers it or holds it as a draft;
//   * a credit note is a `kb_credit_voucher`, the same way;
//   * a receipt is a payment on its invoice, found by the invoice's number.
//
// A document is read back by its number: bexio holds exactly one document
// per legal number, and it is this delivery's when it carries the
// delivery's `api_reference` and total.
//
// Pure: `fetch` is a parameter, so the tests play bexio and no request
// leaves a test run (adapter_test.ts). The live exchange is NOT RUN: it
// needs a bexio test company and a token or a registered app. Every field
// name follows the bexio API reference as far as it could be read without
// an account; a mapping not verified against the live API says so in a
// `// spec:` comment naming where to check.

import type {
  AccountingMap,
  CreateOutcome,
  DeliveryJob,
  MapNeed,
  RemoteAdapter,
  RemoteDocument,
} from "../_shared/accounting_delivery.ts";
import { exponentOf, toMajor } from "../_shared/money.ts";

export type Config = Record<string, string>;
export type Fetch = typeof fetch;

/** The config fields a delivery cannot run without: the API host, the
 * token, and the bexio user documents are created in the name of.
 * spec: docs.bexio.com — "kb_invoice" → user_id is required. */
export const requiredFields = ["base_url", "access_token", "user_id"] as const;

/** One position of a document, net, in integer minor units. */
export interface BexioLine {
  label: string;
  netMinor: number;
  /** The tax component key (`VAT|CH|taxed|8.1|2024`) the connection maps
   * to a bexio `tax_id`. */
  taxKey: string;
  /** The revenue role (`revenue:standard`) the connection maps to a bexio
   * `account_id`. */
  accountKey: string;
}

/** A document event as the app holds it. */
export interface BexioDocument {
  /** The app's document id. */
  id: string;
  kind: "invoice" | "credit_note" | "receipt";
  /** The legal number; for a receipt, its invoice's number. */
  number: string;
  /** YYYY-MM-DD: the issue day, or the day a receipt was paid. */
  date: string;
  /** YYYY-MM-DD; the issue day when the document has no due day. */
  dueDate?: string;
  currency: string;
  /** The customer's party key (`member:<uuid>`), mapped to a contact. */
  partyKey: string;
  title: string;
  lines: BexioLine[];
  /** The gross total (a credit note's as a positive amount), or the amount
   * a receipt paid, minor units. */
  totalMinor: number;
}

/** The mapping keys [doc] needs on the connection: its customer and each
 * position's tax and account. A receipt needs none: it lands on its
 * invoice. */
export function needsOf(doc: BexioDocument): MapNeed[] {
  if (doc.kind === "receipt") return [];
  return [
    { kind: "party", key: doc.partyKey },
    ...doc.lines.flatMap((l): MapNeed[] => [
      { kind: "tax", key: l.taxKey },
      { kind: "account", key: l.accountKey },
    ]),
  ];
}

/** Minor units → the decimal string bexio reads, from the digits. */
export function amount(minor: number, currency: string): string {
  if (exponentOf(currency) === null) throw new Error(`unsupported ${currency}`);
  return toMajor(minor, currency);
}

const join = (base: string, path: string): string =>
  `${base.replace(/\/+$/, "")}/${path.replace(/^\/+/, "")}`;

type Call =
  | { ok: true; body: unknown }
  | { ok: false; unknown: boolean; detail: string };

async function call(
  fetchImpl: Fetch,
  cfg: Config,
  path: string,
  init: RequestInit = {},
): Promise<Call> {
  let res: Response;
  try {
    res = await fetchImpl(join(cfg.base_url, path), {
      ...init,
      headers: {
        authorization: `Bearer ${cfg.access_token}`,
        accept: "application/json",
        ...(init.body ? { "content-type": "application/json" } : {}),
        ...(init.headers ?? {}),
      },
    });
  } catch (error) {
    // No answer: the request may have landed.
    return { ok: false, unknown: true, detail: String(error).slice(0, 500) };
  }
  const text = (await res.text()).slice(0, 4000);
  if (!res.ok) {
    // A 5xx after a write may have landed too; a 4xx is bexio's refusal.
    return {
      ok: false,
      unknown: res.status >= 500,
      detail: `${res.status} ${text.slice(0, 500)}`,
    };
  }
  try {
    return { ok: true, body: text ? JSON.parse(text) : {} };
  } catch {
    return { ok: true, body: {} };
  }
}

const post = (fetchImpl: Fetch, cfg: Config, path: string, body: unknown) =>
  call(fetchImpl, cfg, path, { method: "POST", body: JSON.stringify(body) });

/** The bexio resource of a document kind. */
const resourceOf = (kind: BexioDocument["kind"]): string =>
  kind === "credit_note" ? "kb_credit_voucher" : "kb_invoice";

/** What [maps] names for [kind] [key] on bexio, as a number. */
function mappedId(maps: AccountingMap[], kind: MapNeed["kind"], key: string): number {
  const m = maps.find((x) => x.kind === kind && x.key === key);
  return Number(m?.remoteId || m?.remoteCode);
}

/** The body of `POST /2.0/kb_invoice` (or kb_credit_voucher): the document
 * with its legal number, the delivery's [idempotencyKey], net positions on
 * the mapped tax and account, for [currencyId].
 * spec: docs.bexio.com — "Create invoice": document_nr is writable only
 * where the company numbers documents by hand (Settings → Documents);
 * mwst_type 1 = prices without tax, mwst_is_net true. */
export function documentPayload(
  doc: BexioDocument,
  idempotencyKey: string,
  maps: AccountingMap[],
  ids: { userId: number; currencyId: number },
): Record<string, unknown> {
  const c = doc.currency.toUpperCase();
  return {
    document_nr: doc.number,
    title: doc.title,
    contact_id: mappedId(maps, "party", doc.partyKey),
    user_id: ids.userId,
    currency_id: ids.currencyId,
    mwst_type: 1,
    mwst_is_net: true,
    is_valid_from: doc.date,
    is_valid_to: doc.dueDate ?? doc.date,
    api_reference: idempotencyKey,
    positions: doc.lines.map((l) => ({
      type: "KbPositionCustom",
      text: l.label,
      amount: "1",
      unit_price: amount(Math.abs(l.netMinor), c),
      tax_id: mappedId(maps, "tax", l.taxKey),
      account_id: mappedId(maps, "account", l.accountKey),
    })),
  };
}

/** The bexio id of [currency] (`GET /3.0/currencies`). */
async function currencyId(
  fetchImpl: Fetch,
  cfg: Config,
  currency: string,
): Promise<number | string> {
  const listed = await call(fetchImpl, cfg, "3.0/currencies");
  if (!listed.ok) return listed.detail;
  const found = (Array.isArray(listed.body) ? listed.body : []).find(
    (x: Record<string, unknown>) => String(x.name).toUpperCase() === currency.toUpperCase(),
  );
  return found ? Number(found.id) : `currency ${currency} is not in the bexio company`;
}

/** The bexio documents of [kind] numbered [number]
 * (`POST /2.0/<resource>/search`). */
async function byNumber(
  fetchImpl: Fetch,
  cfg: Config,
  kind: BexioDocument["kind"],
  number: string,
): Promise<Record<string, unknown>[] | string> {
  const found = await post(fetchImpl, cfg, `2.0/${resourceOf(kind)}/search`, [
    { field: "document_nr", value: number, criteria: "=" },
  ]);
  if (!found.ok) return found.detail;
  return Array.isArray(found.body) ? found.body as Record<string, unknown>[] : [];
}

/** The key of a document event among the adapter's documents: an invoice
 * and the receipt that pays it share the document id. */
export const documentKey = (kind: string, id: string): string => `${kind}:${id}`;

/** The adapter over [documents] (by [documentKey]): what the kit runs. */
export function bexioAdapter(
  documents: Record<string, BexioDocument>,
  { fetch: fetchImpl, config }: { fetch: Fetch; config: Config },
): RemoteAdapter {
  const docOf = (job: DeliveryJob) => documents[documentKey(job.documentKind, job.documentId)];
  return {
    async readback(idempotencyKey, job): Promise<RemoteDocument[] | string> {
      const doc = docOf(job);
      if (!doc) return `no document ${job.documentId}`;
      const held = await byNumber(fetchImpl, config, doc.kind === "receipt" ? "invoice" : doc.kind, doc.number);
      if (typeof held === "string") return held;
      if (doc.kind !== "receipt") {
        return held.map((r) => ({
          id: String(r.id),
          number: String(r.document_nr ?? ""),
          state: "posted",
          // spec: "kb_invoice" → total is the gross as a decimal string.
          matches: r.api_reference === idempotencyKey &&
            String(r.total) === amount(doc.totalMinor, doc.currency.toUpperCase()),
        }));
      }
      if (held.length !== 1) return `invoice ${doc.number}: ${held.length} documents in bexio`;
      const paid = await call(fetchImpl, config, `2.0/kb_invoice/${held[0].id}/payment`);
      if (!paid.ok) return paid.detail;
      return (Array.isArray(paid.body) ? paid.body as Record<string, unknown>[] : [])
        .filter((p) => p.date === doc.date)
        .map((p) => ({
          id: String(p.id),
          state: "posted",
          matches: String(p.value) === amount(doc.totalMinor, doc.currency.toUpperCase()),
        }));
    },

    async create(idempotencyKey, job, maps): Promise<CreateOutcome> {
      const doc = docOf(job);
      if (!doc) return { ok: false, unknown: false, detail: `no document ${job.documentId}` };
      const missing = requiredFields.filter((f) => !config[f]);
      if (missing.length > 0) {
        return { ok: false, unknown: false, detail: `missing ${missing.join(", ")}` };
      }
      if (exponentOf(doc.currency) === null) {
        return { ok: false, unknown: false, detail: `unsupported ${doc.currency}` };
      }
      if (doc.kind === "receipt") {
        const held = await byNumber(fetchImpl, config, "invoice", doc.number);
        if (typeof held === "string") return { ok: false, unknown: false, detail: held };
        if (held.length !== 1) {
          return { ok: false, unknown: false, detail: `invoice ${doc.number} is not in bexio once` };
        }
        // spec: "Create payment" → date and value; bank_account_id optional.
        const paid = await post(fetchImpl, config, `2.0/kb_invoice/${held[0].id}/payment`, {
          date: doc.date,
          value: amount(doc.totalMinor, doc.currency.toUpperCase()),
        });
        if (!paid.ok) return { ok: false, unknown: paid.unknown, detail: paid.detail };
        const body = paid.body as Record<string, unknown>;
        return { ok: true, remote: { id: String(body.id), state: "posted", matches: true } };
      }
      const currency = await currencyId(fetchImpl, config, doc.currency);
      if (typeof currency === "string") return { ok: false, unknown: false, detail: currency };
      const resource = resourceOf(doc.kind);
      const created = await post(
        fetchImpl,
        config,
        `2.0/${resource}`,
        documentPayload(doc, idempotencyKey, maps, {
          userId: Number(config.user_id),
          currencyId: currency,
        }),
      );
      if (!created.ok) return { ok: false, unknown: created.unknown, detail: created.detail };
      const body = created.body as Record<string, unknown>;
      // Issued, never left a draft: an issue that has no answer leaves the
      // document unknown, and the next run reads it back by its number.
      const issued = await post(fetchImpl, config, `2.0/${resource}/${body.id}/issue`, {});
      if (!issued.ok) return { ok: false, unknown: true, detail: `issue: ${issued.detail}` };
      return {
        ok: true,
        remote: { id: String(body.id), number: String(body.document_nr ?? doc.number), state: "posted", matches: true },
      };
    },
  };
}
