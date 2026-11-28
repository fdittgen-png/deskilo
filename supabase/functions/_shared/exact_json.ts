// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 (E03A, slice 2) -- JSON whose numbers keep every digit. A till board's amounts are signed 64-bit integers and
// PostgreSQL answers `bigint` columns as bare integer tokens; `JSON.parse` reads both through an IEEE double and silently
// turns 2^53 + 1 into 2^53. This reader keeps an integer token as a BigInt and any other number as its own text, and the
// writer prints them back byte for byte. It is bounded: a body past its bytes, a value nested past its depth or a body of
// more values than its ceiling is refused before anything is built from it. E01 (#4452) may adopt it as the protocol's
// codec.

/** A number that is not an integer, kept as the text it was written with (`20.0`, `1e-3`). */
export class ExactDecimal {
  constructor(readonly text: string) {}
}

export type ExactValue =
  | null
  | boolean
  | string
  | bigint
  | ExactDecimal
  | ExactValue[]
  | { [key: string]: ExactValue };

export type ExactLimits = { maxBytes: number; maxDepth: number; maxValues: number };

/** Why a body is not read. */
export type ExactRefusal = "payload_too_large" | "too_deep" | "too_many_values" | "invalid_utf8" | "invalid_json";

export class ExactJsonError extends Error {
  constructor(readonly reason: ExactRefusal) {
    super(reason);
  }
}

export const I64_MIN = -(2n ** 63n);
export const I64_MAX = 2n ** 63n - 1n;

/** [v] as a signed 64-bit integer, or null when it is none (not an integer, or outside the range). */
export function asI64(v: ExactValue | undefined): bigint | null {
  return typeof v === "bigint" && v >= I64_MIN && v <= I64_MAX ? v : null;
}

/** Reads [bytes] (UTF-8) within [limits]. */
export function parseExactBytes(bytes: Uint8Array, limits: ExactLimits): ExactValue {
  if (bytes.length > limits.maxBytes) throw new ExactJsonError("payload_too_large");
  let text: string;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch (_e) { // handled: an undecodable body is refused with its reason
    throw new ExactJsonError("invalid_utf8");
  }
  return parseExact(text, limits);
}

/** Reads [text] within [limits]. */
export function parseExact(text: string, limits: ExactLimits): ExactValue {
  if (new TextEncoder().encode(text).length > limits.maxBytes) throw new ExactJsonError("payload_too_large");
  let at = 0;
  let values = 0;
  const fail = (): never => {
    throw new ExactJsonError("invalid_json");
  };
  const space = () => {
    while (at < text.length && " \t\n\r".includes(text[at])) at++;
  };
  const count = () => {
    if (++values > limits.maxValues) throw new ExactJsonError("too_many_values");
  };
  const str = (): string => {
    const start = at;
    at++; // the opening quote
    while (at < text.length && text[at] !== '"') {
      if (text[at] === "\\") at++;
      else if (text.charCodeAt(at) < 0x20) fail();
      at++;
    }
    if (at >= text.length) fail();
    at++;
    try {
      return JSON.parse(text.slice(start, at)) as string; // a string token alone: its escapes, never a number
    } catch (_e) { // handled: a malformed escape is invalid JSON
      return fail();
    }
  };
  const num = (): bigint | ExactDecimal => {
    const m = /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?/.exec(text.slice(at));
    if (!m) return fail();
    at += m[0].length;
    return m[2] === undefined && m[3] === undefined ? BigInt(m[0]) : new ExactDecimal(m[0]);
  };
  const value = (depth: number): ExactValue => {
    if (depth > limits.maxDepth) throw new ExactJsonError("too_deep");
    space();
    count();
    const c = text[at];
    if (c === "{") {
      at++;
      const out: { [key: string]: ExactValue } = {};
      space();
      if (text[at] === "}") {
        at++;
        return out;
      }
      for (;;) {
        space();
        if (text[at] !== '"') fail();
        const key = str();
        space();
        if (text[at++] !== ":") fail();
        Object.defineProperty(out, key, { value: value(depth + 1), enumerable: true, writable: true, configurable: true });
        space();
        if (text[at] === ",") {
          at++;
          continue;
        }
        if (text[at++] !== "}") fail();
        return out;
      }
    }
    if (c === "[") {
      at++;
      const out: ExactValue[] = [];
      space();
      if (text[at] === "]") {
        at++;
        return out;
      }
      for (;;) {
        out.push(value(depth + 1));
        space();
        if (text[at] === ",") {
          at++;
          continue;
        }
        if (text[at++] !== "]") fail();
        return out;
      }
    }
    if (c === '"') return str();
    if (text.startsWith("true", at)) return (at += 4, true);
    if (text.startsWith("false", at)) return (at += 5, false);
    if (text.startsWith("null", at)) return (at += 4, null);
    return num();
  };
  const out = value(1);
  space();
  if (at !== text.length) fail();
  return out;
}

/** [v] as JSON, every integer and decimal printed with exactly the digits it holds. */
export function stringifyExact(v: ExactValue): string {
  if (v === null) return "null";
  if (typeof v === "boolean") return v ? "true" : "false";
  if (typeof v === "string") return JSON.stringify(v);
  if (typeof v === "bigint") return v.toString();
  if (v instanceof ExactDecimal) return v.text;
  if (Array.isArray(v)) return "[" + v.map(stringifyExact).join(",") + "]";
  return "{" + Object.entries(v).map(([k, x]) => JSON.stringify(k) + ":" + stringifyExact(x)).join(",") + "}";
}
