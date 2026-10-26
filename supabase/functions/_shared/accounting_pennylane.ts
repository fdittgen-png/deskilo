// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the adapter of the accounting target `pennylane_api`: the
// Pennylane external API v2, the most used SME accounting platform in
// France. The delivery kit sends it the postings of a period, each one a
// balanced ledger entry in the company's journal of its code, read back by
// its external reference (the delivery's idempotency key), so a document
// Pennylane already holds is never created twice. Importing invoices as
// customer invoices with their PDF/A-3 needs the PDF on the server, which
// the app alone builds today.
//
// The adapter is pure and takes `fetch` as a parameter, so the tests play
// Pennylane and no request leaves a test run (accounting_pennylane_test.ts).
// The live exchange is NOT RUN: it needs a Pennylane sandbox company the
// owner opens. It sits flat in `_shared/` because only that directory is
// deployed beside a function; `accounting-connect` runs it through the
// delivery kit (`pennylaneLedger` below: the postings of a period as
// ledger entries, read back by their idempotency key).
//
// Every field name follows the Pennylane API v2 reference as far as it
// could be read without an account; a mapping not yet verified against
// the live API says so in a `// spec:` comment naming where to check.

import { exponentOf, toMajor, toMinor } from "./money.ts";
import {
  accountNeeds,
  type AdapterContext,
  mapped,
  type Posting,
  type PostingAdapter,
  roleKey,
} from "./accounting_postings.ts";

export type Config = Record<string, string>;
export type Fetch = typeof fetch;

/** Pennylane documents no shared sandbox host: a sandbox is a test
 * company on the production API, so the base URL is the same and the
 * token decides which company is written to.
 * spec: developers.pennylane.com — "Sandbox" / "Getting started". */
export const SANDBOX: Config = {
  base_url: "https://app.pennylane.com/api/external/v2",
};

/** A payment or write-off, as a balanced entry of the books. */
export interface PennylaneJournalEntry {
  /** The app's posting id: the entry's external reference. */
  id: string;
  /** YYYY-MM-DD. */
  date: string;
  /** The app's journal code (BQ, OD). */
  journalCode: string;
  label: string;
  /** The document the entry settles, by its legal number. */
  documentReference: string;
  currency: string;
  lines: {
    account: string;
    debitMinor: number;
    creditMinor: number;
    label?: string;
  }[];
}

/** Why something was not delivered. Never thrown: returned. */
export type FailureReason =
  | "reauth_needed" // 401: the token is gone; the kit refreshes or asks
  | "rejected" // 422 and other 4xx: Pennylane said no, with its words
  | "retry_later" // 429 and 5xx: try again later
  | "unbalanced" // an entry whose debits and credits differ
  | "unsupported" // a currency or VAT rate the adapter cannot state
  | "unreachable"; // no answer at all

export interface Failure {
  reason: FailureReason;
  detail: string;
}

/** A typed refusal while building a payload. */
export class PayloadRefusal extends Error {
  constructor(readonly failure: Failure) {
    super(`${failure.reason}: ${failure.detail}`);
    this.name = "PayloadRefusal";
  }
}

/** Minor units → the decimal string Pennylane reads, from the digits. */
export function amount(minor: number, currency: string): string {
  if (exponentOf(currency) === null) {
    throw new PayloadRefusal({ reason: "unsupported", detail: currency });
  }
  return toMajor(minor, currency);
}

/** The body of `POST /ledger_entries` for a payment or write-off, its
 * accounts and journal resolved to Pennylane ids by [accountIds] (by
 * number) and [journalId]. Throws [PayloadRefusal] when the entry does not
 * balance or names an account Pennylane does not hold. */
export function journalEntryPayload(
  entry: PennylaneJournalEntry,
  accountIds: Record<string, number>,
  journalId: number,
): Record<string, unknown> {
  const c = entry.currency.toUpperCase();
  let debit = 0;
  let credit = 0;
  for (const l of entry.lines) {
    if (
      !Number.isInteger(l.debitMinor) || !Number.isInteger(l.creditMinor) ||
      l.debitMinor < 0 || l.creditMinor < 0 ||
      (l.debitMinor === 0) === (l.creditMinor === 0)
    ) {
      throw new PayloadRefusal({
        reason: "unbalanced",
        detail: `${entry.documentReference}: a line is one debit or one credit`,
      });
    }
    debit += l.debitMinor;
    credit += l.creditMinor;
  }
  if (entry.lines.length < 2 || debit !== credit) {
    throw new PayloadRefusal({
      reason: "unbalanced",
      detail: `${entry.documentReference}: debit ${debit} ≠ credit ${credit}`,
    });
  }
  return {
    date: entry.date,
    label: entry.label,
    journal_id: journalId,
    // spec: "Create a ledger entry" — whether ledger_entries take an
    // external_reference or only a label/piece number.
    external_reference: entry.id,
    piece_number: entry.documentReference,
    currency: c,
    ledger_entry_lines: entry.lines.map((l) => {
      const id = accountIds[l.account];
      if (id === undefined) {
        throw new PayloadRefusal({
          reason: "rejected",
          detail: `account ${l.account} is not in the Pennylane chart`,
        });
      }
      return {
        ledger_account_id: id,
        label: l.label ?? entry.label,
        debit: amount(l.debitMinor, c),
        credit: amount(l.creditMinor, c),
      };
    }),
  };
}

const join = (base: string, path: string): string =>
  `${base.replace(/\/+$/, "")}/${path.replace(/^\/+/, "")}`;

/** The filter query Pennylane v2 lists take: a JSON array of conditions.
 * spec: API v2 "Filtering" — `filter=[{field, operator, value}]`. */
const byField = (field: string, value: string): string =>
  `filter=${
    encodeURIComponent(JSON.stringify([{ field, operator: "eq", value }]))
  }`;

/** An HTTP answer that is not a success, as a typed failure. */
async function failureOf(res: Response): Promise<Failure> {
  const text = (await res.text()).slice(0, 500);
  if (res.status === 401) return { reason: "reauth_needed", detail: text };
  if (res.status === 429 || res.status >= 500) {
    return { reason: "retry_later", detail: `${res.status} ${text}` };
  }
  let message = text;
  try {
    const body = JSON.parse(text);
    if (body && typeof body === "object") {
      message = String(body.message ?? body.error ?? text);
    }
  } catch {
    // Not JSON: Pennylane's words as they came.
  }
  return { reason: "rejected", detail: `${res.status} ${message}` };
}

type Call = { ok: true; body: Record<string, unknown> } | {
  ok: false;
  failure: Failure;
  /** The HTTP status, absent when nothing answered. */
  status?: number;
};

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
        ...(init.headers ?? {}),
      },
    });
  } catch (error) {
    return {
      ok: false,
      failure: { reason: "unreachable", detail: String(error).slice(0, 500) },
    };
  }
  if (!res.ok) {
    return { ok: false, failure: await failureOf(res), status: res.status };
  }
  const text = await res.text();
  try {
    const body = text ? JSON.parse(text) : {};
    return { ok: true, body: body && typeof body === "object" ? body : {} };
  } catch {
    return { ok: true, body: {} };
  }
}

// ── the delivery kit: postings as ledger entries ──────────────────────────

/** The usual code of each journal of the posting engine, the code a
 * French chart's journal carries (PostingJournal in posting.dart; pinned to
 * it by test/features/money/accounting_targets_test.dart). A Pennylane
 * company's journal is found by it. */
export const JOURNAL_CODES: Record<string, string> = {
  sales: "VE",
  bank: "BQ",
  purchases: "HA",
  other: "OD",
};

/** The journals of the company by code, every page of them.
 * spec: API v2 "List journals" — items with id and code; cursor pagination
 * (`has_more`, `next_cursor`). */
async function journalIds(
  fetchImpl: Fetch,
  cfg: Config,
): Promise<{ ids: Record<string, number> } | { failure: Failure }> {
  const ids: Record<string, number> = {};
  let path = "journals";
  for (;;) {
    const page = await call(fetchImpl, cfg, path);
    if (!page.ok) return { failure: page.failure };
    const items = Array.isArray(page.body.items) ? page.body.items : [];
    for (const j of items as Record<string, unknown>[]) {
      if (typeof j.code === "string") ids[j.code] = Number(j.id);
    }
    const next = page.body.next_cursor;
    if (page.body.has_more !== true || typeof next !== "string" || !next) {
      return { ids };
    }
    path = `journals?cursor=${encodeURIComponent(next)}`;
  }
}

/** Whether a send that got [status] (none: no answer) may have created. */
const outcomeUnknown = (status?: number): boolean =>
  status === undefined || status >= 500;

/** How the ledger entry [e] Pennylane holds differs from [posting]: its
 * day, and its debits and credits summed (an entry edited at the target is
 * not ours any more). spec: "List ledger entries" — each item carries its
 * `ledger_entry_lines` with decimal `debit` and `credit`; an item without
 * them cannot be compared and is a difference. */
function differencesOf(e: Record<string, unknown>, posting: Posting): string[] {
  const out: string[] = [];
  if (e.date !== posting.date) out.push(`dated ${e.date}`);
  const lines = e.ledger_entry_lines;
  if (!Array.isArray(lines)) return [...out, "Pennylane shows no lines to compare"];
  const sum = (side: "debit" | "credit") =>
    (lines as Record<string, unknown>[]).reduce<number | null>((s, l) => {
      const v = toMinor(String(l[side] ?? "0"), posting.currency);
      return s === null || v === null ? null : s + v;
    }, 0);
  const debit = posting.lines.reduce((s, l) => s + l.debitCents, 0);
  const credit = posting.lines.reduce((s, l) => s + l.creditCents, 0);
  if (sum("debit") !== debit || sum("credit") !== credit) {
    out.push(`Pennylane's lines sum to other amounts than the document's ${toMajor(debit, posting.currency)}`);
  }
  return out;
}

/** The Pennylane adapter of the delivery kit: every posting of a period a
 * balanced ledger entry in the journal of its code, each line on the
 * Pennylane ledger account its role is mapped to (`account` mappings,
 * remote id = the ledger account's id), the entry's external reference the
 * delivery's idempotency key, so a readback finds exactly this delivery. */
export function pennylaneLedger(ctx: AdapterContext): PostingAdapter {
  const cfg: Config = {
    base_url: SANDBOX.base_url,
    access_token: ctx.secrets.access_token ?? "",
  };
  let journals: Record<string, number> = {};
  return {
    async prepare() {
      if (!cfg.access_token) return "the connection holds no token";
      const found = await journalIds(ctx.fetch, cfg);
      if ("failure" in found) return found.failure.detail;
      journals = found.ids;
      return null;
    },
    needs: accountNeeds,
    remote(posting, party, maps) {
      return {
        async readback(key) {
          // spec: "List ledger entries" — external_reference filterable.
          const found = await call(
            ctx.fetch,
            cfg,
            `ledger_entries?${byField("external_reference", key)}`,
          );
          if (!found.ok) return found.failure.detail;
          const items = Array.isArray(found.body.items) ? found.body.items : [];
          return (items as Record<string, unknown>[]).map((e) => {
            const differences = differencesOf(e, posting);
            return {
              id: String(e.id),
              number: typeof e.piece_number === "string" ? e.piece_number : "",
              state: "posted" as const,
              matches: differences.length === 0,
              difference: differences.length > 0 ? differences.join("; ") : undefined,
            };
          });
        },
        async create(key) {
          const code = JOURNAL_CODES[posting.journal] ?? "";
          const journalId = journals[code];
          if (journalId === undefined) {
            return {
              ok: false,
              unknown: false,
              detail: `the journal ${code || posting.journal} is not in this Pennylane company`,
            };
          }
          const accountIds: Record<string, number> = {};
          for (const need of accountNeeds(posting)) {
            const id = Number(mapped(maps, "account", need.key));
            if (!Number.isSafeInteger(id) || id <= 0) {
              return {
                ok: false,
                unknown: false,
                detail: `account ${need.key}: name the Pennylane ledger account by its id`,
              };
            }
            accountIds[need.key] = id;
          }
          let body: Record<string, unknown>;
          try {
            body = journalEntryPayload({
              id: key,
              date: posting.date,
              journalCode: code,
              label: [posting.documentNumber, party?.name ?? ""].filter(Boolean).join(" "),
              documentReference: posting.documentNumber,
              currency: posting.currency,
              lines: posting.lines.map((l) => ({
                account: roleKey(l),
                debitMinor: l.debitCents,
                creditMinor: l.creditCents,
              })),
            }, accountIds, journalId);
          } catch (error) {
            if (error instanceof PayloadRefusal) {
              return { ok: false, unknown: false, detail: error.failure.detail };
            }
            throw error;
          }
          const sent = await call(ctx.fetch, cfg, "ledger_entries", {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify(body),
          });
          if (!sent.ok) {
            return { ok: false, unknown: outcomeUnknown(sent.status), detail: sent.failure.detail };
          }
          return {
            ok: true,
            remote: {
              id: String(sent.body.id),
              number: posting.documentNumber,
              state: "posted",
              matches: true,
            },
          };
        },
      };
    },
  };
}
