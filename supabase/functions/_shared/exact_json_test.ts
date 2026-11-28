// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 (E03A, slice 2) -- the exact JSON codec on the issue's money fixtures: 2^53 - 1, 2^53, 2^53 + 1, the signed
// 64-bit bounds and one beyond them read and printed digit for digit; decimals kept as written; the body's bytes, depth
// and value count bounded; invalid UTF-8 and malformed JSON refused with their reasons.
import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  asI64,
  ExactDecimal,
  ExactJsonError,
  type ExactLimits,
  I64_MAX,
  I64_MIN,
  parseExact,
  parseExactBytes,
  stringifyExact,
} from "./exact_json.ts";

const LIMITS: ExactLimits = { maxBytes: 4096, maxDepth: 8, maxValues: 256 };

const refusal = (f: () => unknown) => {
  try {
    f();
  } catch (e) { // handled: the test reads the refusal's reason
    if (e instanceof ExactJsonError) return e.reason;
    throw e;
  }
  return "none";
};

Deno.test("integers keep every digit both ways, past what a double holds", () => {
  for (
    const token of [
      "9007199254740991", // 2^53 - 1
      "9007199254740992", // 2^53
      "9007199254740993", // 2^53 + 1, which JSON.parse reads as 2^53
      "9223372036854775807", // i64 max
      "-9223372036854775808", // i64 min
      "0",
      "-30",
    ]
  ) {
    const v = parseExact(`{"total_minor":${token}}`, LIMITS) as { total_minor: bigint };
    assertEquals(v.total_minor, BigInt(token));
    assertEquals(stringifyExact(v), `{"total_minor":${token}}`);
  }
  assertEquals(JSON.parse('{"a":9007199254740993}').a, 9007199254740992, "the trap the codec exists for");
});

Deno.test("the signed 64-bit range is checked, one beyond it on either side is no amount", () => {
  assertEquals(asI64(parseExact("9223372036854775807", LIMITS)), I64_MAX);
  assertEquals(asI64(parseExact("-9223372036854775808", LIMITS)), I64_MIN);
  assertEquals(asI64(parseExact("9223372036854775808", LIMITS)), null);
  assertEquals(asI64(parseExact("-9223372036854775809", LIMITS)), null);
  assertEquals(asI64(parseExact("12.5", LIMITS)), null, "a decimal is no integer amount");
  assertEquals(asI64(parseExact('"1250"', LIMITS)), null, "nor a string");
});

Deno.test("a decimal is kept as written", () => {
  const v = parseExact('{"percent":20.0,"tiny":1e-3}', LIMITS) as { percent: ExactDecimal; tiny: ExactDecimal };
  assert(v.percent instanceof ExactDecimal);
  assertEquals(stringifyExact(v), '{"percent":20.0,"tiny":1e-3}');
});

Deno.test("strings, escapes, nesting and the literals read as JSON does", () => {
  const text = '{"name":"Caf\\u00e9 \\"au lait\\"","lines":[{"qty":2},[],{}],"ok":true,"no":false,"none":null}';
  const v = parseExact(text, LIMITS) as { name: string };
  assertEquals(v.name, 'Café "au lait"');
  assertEquals(stringifyExact(v), '{"name":"Café \\"au lait\\"","lines":[{"qty":2},[],{}],"ok":true,"no":false,"none":null}');
});

Deno.test("a body past its bytes, a value past its depth or a body of too many values is refused", () => {
  const big = '"' + "x".repeat(LIMITS.maxBytes) + '"';
  assertEquals(refusal(() => parseExact(big, LIMITS)), "payload_too_large");
  const at = '"' + "x".repeat(LIMITS.maxBytes - 2) + '"';
  assertEquals(typeof parseExact(at, LIMITS), "string", "exactly the largest body is read");
  assertEquals(refusal(() => parseExact("[".repeat(9) + "]".repeat(9), LIMITS)), "too_deep");
  assertEquals(typeof parseExact("[".repeat(7) + "]".repeat(7), LIMITS), "object");
  assertEquals(refusal(() => parseExact("[" + Array(300).fill("1").join(",") + "]", LIMITS)), "too_many_values");
});

Deno.test("invalid UTF-8 and malformed JSON are refused with their reasons", () => {
  assertEquals(refusal(() => parseExactBytes(new Uint8Array([0x7b, 0xff, 0x7d]), LIMITS)), "invalid_utf8");
  for (const bad of ["", "{", '{"a":}', '{"a" 1}', "[1,]", "01", "1.", "-", "tru", '"\u0001"', '{"a":1}x', "NaN"]) {
    assertEquals(refusal(() => parseExact(bad, LIMITS)), "invalid_json", bad);
  }
  assertThrows(() => parseExact("[1,", LIMITS), ExactJsonError);
});

Deno.test("a key named __proto__ is a plain key, never the object's prototype", () => {
  const v = parseExact('{"__proto__":{"polluted":1}}', LIMITS) as Record<string, unknown>;
  assertEquals(Object.getPrototypeOf(v), Object.prototype);
  assert(Object.prototype.hasOwnProperty.call(v, "__proto__"));
  assertEquals(({} as Record<string, unknown>).polluted, undefined);
});
