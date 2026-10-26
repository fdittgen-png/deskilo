// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a connection delivery carries: the postings of a period as the
// posting engine answers them (`compute_postings`), one per document event,
// each balanced to the cent. Every adapter serialises the same postings,
// so a target never sees a second computation of a document. This module
// reads the engine's answer, names the mapping keys a posting's lines use
// and digests a posting's content; the adapters (`accounting_pennylane.ts`,
// `accounting_quickbooks.ts`) turn a posting into their target's objects.

import type { AccountingMap, MapNeed, RemoteAdapter } from "./accounting_delivery.ts";

export interface PostingLine {
  /** The book role (`customers`, `revenue`, `vat_output`, ...). */
  role: string;
  /** The rate group or provider of a qualified role, null for the base. */
  qualifier: string | null;
  debitCents: number;
  creditCents: number;
}

/** One entry of the books: one document event, one date, one journal. */
export interface Posting {
  /** The journal by its name in the engine (`sales`, `bank`, ...). */
  journal: string;
  /** The document event (`invoice`, `credit_note`, `receipt`, ...). */
  kind: string;
  /** YYYY-MM-DD. */
  date: string;
  documentId: string;
  documentNumber: string;
  currency: string;
  lines: PostingLine[];
}

/** The third party of a posted document (`posting_parties`). */
export interface PostingParty {
  /** `member` or `supplier`. */
  kind: string;
  number: string;
  name: string;
}

/** What stops the postings of a period (`compute_postings` blockers). */
export interface PostingBlocker {
  block: string;
  subject: string;
}

const text = (v: unknown): string => (typeof v === "string" ? v : "");
const cents = (v: unknown): number => {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isSafeInteger(n) || n < 0) throw new Error(`not an amount in cents: ${v}`);
  return n;
};

/** The engine's answer as postings and blockers; throws on another shape. */
export function postingsOf(raw: unknown): { postings: Posting[]; blockers: PostingBlocker[] } {
  if (typeof raw !== "object" || raw === null) throw new Error("compute_postings: no answer");
  const body = raw as Record<string, unknown>;
  const list = (v: unknown): Record<string, unknown>[] =>
    Array.isArray(v) ? v.filter((x) => typeof x === "object" && x !== null) as Record<string, unknown>[] : [];
  return {
    postings: list(body.postings).map((p) => ({
      journal: text(p.journal),
      kind: text(p.kind),
      date: text(p.date),
      documentId: text(p.document_id),
      documentNumber: text(p.document_number),
      currency: text(p.currency).toUpperCase(),
      lines: list(p.lines).map((l) => ({
        role: text(l.role),
        qualifier: text(l.qualifier) || null,
        debitCents: cents(l.debit_cents ?? 0),
        creditCents: cents(l.credit_cents ?? 0),
      })),
    })),
    blockers: list(body.blockers).map((b) => ({ block: text(b.block), subject: text(b.subject) })),
  };
}

/** The mapping key of a line's role: `revenue:standard`, `bank`. */
export function roleKey(line: Pick<PostingLine, "role" | "qualifier">): string {
  return line.qualifier ? `${line.role}:${line.qualifier}` : line.role;
}

/** The `account` needs of every line of [posting], once each. */
export function accountNeeds(posting: Posting): MapNeed[] {
  return [...new Set(posting.lines.map(roleKey))].map((key) => ({ kind: "account" as const, key }));
}

/** Debits equal credits, exactly, over at least two lines. */
export function balanced(posting: Posting): boolean {
  let debit = 0;
  let credit = 0;
  for (const l of posting.lines) {
    debit += l.debitCents;
    credit += l.creditCents;
  }
  return posting.lines.length >= 2 && debit === credit;
}

/** The sha256 of a posting's content, lowercase hex: its event, its day,
 * its document and its lines by role and amount. The local chart's account
 * codes and the connection's mappings are not part of it, so a changed
 * mapping is not a changed document. */
export async function postingSha256(posting: Posting): Promise<string> {
  const canonical = JSON.stringify([
    posting.journal,
    posting.kind,
    posting.date,
    posting.documentId,
    posting.documentNumber,
    posting.currency,
    posting.lines.map((l) => [l.role, l.qualifier ?? "", l.debitCents, l.creditCents]),
  ]);
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonical));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** What an adapter is given for one run. */
export interface AdapterContext {
  fetch: typeof fetch;
  /** The connection's secrets from Vault (`access_token`). */
  secrets: Record<string, string>;
  /** The remote company the connection reaches, '' when none is named. */
  tenant: string;
  /** The connection's target id. */
  targetId: string;
  env: (name: string) => string | undefined;
}

/** A target that takes postings through the delivery kit. */
export interface PostingAdapter {
  /** Asked once before a run's first document (and after a sign-in): why
   * the target cannot take a delivery now, or null. */
  prepare(): Promise<string | null>;
  /** The mapping keys [posting] needs on this target. */
  needs(posting: Posting): MapNeed[];
  /** The readback and create of [posting] for the kit. */
  remote(posting: Posting, party: PostingParty | undefined, maps: AccountingMap[]): RemoteAdapter;
}

/** The remote id or code a mapping of [kind] [key] names, '' when none. */
export function mapped(maps: AccountingMap[], kind: AccountingMap["kind"], key: string): string {
  const m = maps.find((x) => x.kind === kind && x.key === key);
  return m ? (m.remoteId || m.remoteCode) : "";
}
