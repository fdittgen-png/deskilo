// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the UK nine boxes of a PREPARED VAT return, computed from the
// declaration's own lines, on the server. The client never supplies a figure
// that reaches HMRC: the edge function submits (and compares against) these.
//
// This is the TypeScript half of one contract with the Dart form catalogue
// (`vatFormBoxes('GB', …)`, lib/features/money/domain/vat_form_catalogue/gb.dart):
// both reproduce contracts/vat/gb_nine_boxes.json, which
// test/features/money/vat_gb_nine_boxes_contract_test.dart and
// hmrc_boxes_test.ts check.
//
//   box 1  VAT on sales (every output line but an acquisition), in pence
//   box 2  acquisitions from the EU: filed as zero (a coworking space)
//   box 3  box 1 + box 2
//   box 4  VAT reclaimed on purchases (every input line but an acquisition)
//   box 5  |box 3 - box 4|
//   box 6  net of sales, whole pounds, the pence dropped
//   box 7  net of purchases, whole pounds, the pence dropped
//   box 8  and 9 filed as zero

import type { NineBoxes } from "./hmrc_mtd.ts";

const ACQUISITION = "acquisition";

type Line = { input: boolean; acquisition: boolean; net: number; vat: number };

function lineOf(raw: unknown): Line | null {
  if (typeof raw !== "object" || raw === null) return null;
  const l = raw as Record<string, unknown>;
  const net = l.net_cents;
  const vat = l.vat_cents;
  if (!Number.isSafeInteger(net) || !Number.isSafeInteger(vat)) return null;
  return {
    input: l.direction === "input",
    acquisition: l.category === ACQUISITION,
    net: net as number,
    vat: vat as number,
  };
}

/** The sign-preserving whole-unit drop of cents (UK boxes 6 and 7). */
const wholeDown = (cents: number) =>
  Math.sign(cents) * Math.floor(Math.abs(cents) / 100) * 100;

/** Whether [lines] hold an EU acquisition: the UK boxes 2 and 9 are filed as
 * zero for a coworking space, so a return that has one is not submitted
 * from here rather than filed with wrong figures. */
export function hasAcquisitionLines(lines: unknown): boolean {
  return Array.isArray(lines) &&
    lines.some((l) =>
      typeof l === "object" && l !== null &&
      (l as Record<string, unknown>).category === ACQUISITION
    );
}

/** The nine boxes of [lines] (a declaration's `lines`), or null when the
 * lines are not the shape the server stores. */
export function nineBoxesFromLines(lines: unknown): NineBoxes | null {
  if (!Array.isArray(lines)) return null;
  let salesVat = 0;
  let salesNet = 0;
  let inputVat = 0;
  let inputNet = 0;
  for (const raw of lines) {
    const l = lineOf(raw);
    if (!l) return null;
    if (l.acquisition) continue;
    if (l.input) {
      inputVat += l.vat;
      inputNet += l.net;
    } else {
      salesVat += l.vat;
      salesNet += l.net;
    }
  }
  const pounds = (cents: number) => cents / 100;
  const total = salesVat; // box 2 is filed as zero
  return {
    vatDueSales: pounds(salesVat),
    vatDueAcquisitions: 0,
    totalVatDue: pounds(total),
    vatReclaimedCurrPeriod: pounds(inputVat),
    netVatDue: pounds(Math.abs(total - inputVat)),
    totalValueSalesExVAT: wholeDown(salesNet) / 100,
    totalValuePurchasesExVAT: wholeDown(inputNet) / 100,
    totalValueGoodsSuppliedExVAT: 0,
    totalAcquisitionsExVAT: 0,
  };
}

const KEYS: (keyof NineBoxes)[] = [
  "vatDueSales",
  "vatDueAcquisitions",
  "totalVatDue",
  "vatReclaimedCurrPeriod",
  "netVatDue",
  "totalValueSalesExVAT",
  "totalValuePurchasesExVAT",
  "totalValueGoodsSuppliedExVAT",
  "totalAcquisitionsExVAT",
];

/** The boxes in which [sent] differs from [expected], compared in pence
 * (whole pounds included); empty when they agree exactly. */
export function differingBoxes(expected: NineBoxes, sent: NineBoxes): string[] {
  return KEYS.filter((k) =>
    Math.round(expected[k] * 100) !== Math.round(sent[k] * 100)
  );
}
