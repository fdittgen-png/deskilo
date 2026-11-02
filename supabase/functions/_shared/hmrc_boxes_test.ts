// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the server's nine boxes are the Dart form catalogue's: every case of
// contracts/vat/gb_nine_boxes.json (frozen from `vatFormBoxes('GB', …)`) is
// reproduced exactly, and a client figure is compared box by box, in pence.
import { assertEquals } from "jsr:@std/assert@1";
import { differingBoxes, nineBoxesFromLines } from "./hmrc_boxes.ts";
import { returnBody } from "./hmrc_mtd.ts";

const contract = JSON.parse(
  Deno.readTextFileSync(
    new URL("../../../contracts/vat/gb_nine_boxes.json", import.meta.url),
  ),
) as {
  cases: { name: string; lines: unknown; boxes: Record<string, number> }[];
};

for (const c of contract.cases) {
  Deno.test(`the nine boxes of "${c.name}" are the Dart catalogue's, to the penny`, () => {
    const boxes = nineBoxesFromLines(c.lines)!;
    assertEquals(boxes, c.boxes as never);
    // And HMRC's own arithmetic accepts them as a return.
    returnBody("26A1", boxes);
  });
}

Deno.test("any single differing box is found, whichever it is", () => {
  const expected = nineBoxesFromLines(contract.cases[0].lines)!;
  assertEquals(differingBoxes(expected, expected), []);
  for (const key of Object.keys(expected) as (keyof typeof expected)[]) {
    const sent = { ...expected, [key]: expected[key] + 1 };
    assertEquals(differingBoxes(expected, sent), [key], key);
  }
  // Box 6 alone, by a penny worth of pounds the client could slip in.
  assertEquals(
    differingBoxes(expected, {
      ...expected,
      totalValueSalesExVAT: expected.totalValueSalesExVAT + 1,
    }),
    [
      "totalValueSalesExVAT",
    ],
  );
});

Deno.test("lines that are not the server's shape give no boxes", () => {
  assertEquals(nineBoxesFromLines("x"), null);
  assertEquals(nineBoxesFromLines([null]), null);
  assertEquals(nineBoxesFromLines([{ net_cents: "1", vat_cents: 1 }]), null);
  assertEquals(nineBoxesFromLines([{ net_cents: 1.5, vat_cents: 1 }]), null);
});
