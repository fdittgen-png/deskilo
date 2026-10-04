// SPDX-License-Identifier: AGPL-3.0-or-later
//
// get_place — the picture is a real PNG, drawn only from a drawable plan,
// with the place in question in the accent colour.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { drawPlace, encodePng, parseRender, placeImageBase64, PLACE_IMAGE_MAX_PX } from "./place_image.ts";

const PLAN = {
  highlight: { kind: "seat", id: "s1" },
  offices: [["o1", 0, 0, 40, 30, 0]],
  desks: [["d1", "o1", 4, 4, 20, 10]],
  seats: [["s1", "d1", 6, 6, "n"], ["s2", "d1", 14, 6, "e"]],
};

Deno.test("a plan is parsed from its string, anything else is not a plan", () => {
  assert(parseRender(JSON.stringify(PLAN)) !== null);
  assertEquals(parseRender("not json"), null);
  assertEquals(parseRender(JSON.stringify({ ...PLAN, offices: [] })), null);
  assertEquals(parseRender(null), null);
});

Deno.test("the raster fits the bound and the highlight is in the accent colour", () => {
  const { width, height, rgba } = drawPlace(parseRender(JSON.stringify(PLAN))!);
  assert(width <= PLACE_IMAGE_MAX_PX && height <= PLACE_IMAGE_MAX_PX);
  assertEquals(rgba.length, width * height * 4);
  let accent = 0;
  for (let i = 0; i < rgba.length; i += 4) if (rgba[i] === 214 && rgba[i + 1] === 69 && rgba[i + 2] === 65) accent++;
  assert(accent > 20, "the seat in question is drawn in the accent colour");
});

Deno.test("a seat that is not highlighted leaves no accent", () => {
  const { rgba } = drawPlace(parseRender(JSON.stringify({ ...PLAN, highlight: { kind: "seat", id: "none" } }))!);
  for (let i = 0; i < rgba.length; i += 4) assert(!(rgba[i] === 214 && rgba[i + 1] === 69 && rgba[i + 2] === 65));
});

Deno.test("the PNG has the signature, the chunks and the size it was given", async () => {
  const png = await encodePng(3, 2, new Uint8Array(3 * 2 * 4).fill(255));
  assertEquals([...png.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  const dv = new DataView(png.buffer);
  assertEquals(String.fromCharCode(...png.subarray(12, 16)), "IHDR");
  assertEquals([dv.getUint32(16), dv.getUint32(20)], [3, 2]);
  assertEquals(String.fromCharCode(...png.subarray(png.length - 8, png.length - 4)), "IEND");
});

Deno.test("the image is base64 of a PNG, or null for a plan that cannot be drawn", async () => {
  const b64 = await placeImageBase64(JSON.stringify(PLAN));
  assert(b64 !== null && atob(b64).startsWith("\x89PNG"));
  assertEquals(await placeImageBase64("{}"), null);
});
