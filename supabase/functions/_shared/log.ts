// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4412 -- one structured log line per event of an edge function: the function, the
// request, the code and the level, with what must never reach a log left out. A
// failure is one line, never a sentence with a payload in it.

export type Level = "debug" | "info" | "warn" | "error";

/** A key as words: camelCase and `-` become `_`, lower case (`fullName`, `vat-id`, `VATID` -> `full_name`, `vat_id`, `vatid`). */
export function keyWords(key: string): string {
  return key.replace(/([a-z0-9])([A-Z])/g, "$1_$2").replace(/-/g, "_").toLowerCase();
}

/** Fields whose value is a secret or a person's data: their value is replaced. The words of the key are read, singular or plural. */
const REDACTED_WORDS =
  /(?:^|_)(?:authorization|token|tokens|secret|secrets|password|passwd|passwords|api_?key|apikey|credential|credentials|cookie|cookies|signature|iban|ibans|private|bearer|jwt|email|emails|e_mail|phone|phones|mobile|vat_?id|legal_?id|address|addresses|recipient|recipients|username|user_name|first_name|last_name|full_name|display_name|customer_name|contact_name|body|headers)(?:_|$)|^names?$/;

const isRedactedKey = (key: string) => REDACTED_WORDS.test(keyWords(key));

/** How deep a logged object is read: beyond it the value is not logged. */
export const LOG_DEPTH = 4;

/** The longest a logged string stays: a log line is a pointer, not the payload. */
export const LOG_WIDTH = 300;

/** [fields] with the secret and personal ones replaced and long strings clipped; arrays and nested objects are read to LOG_DEPTH, a cycle is cut. */
export function redactFields(
  fields: Record<string, unknown>,
): Record<string, unknown> {
  return redactObject(fields, 0, new WeakSet());
}

function redactObject(
  value: Record<string, unknown>,
  depth: number,
  seen: WeakSet<object>,
): Record<string, unknown> {
  seen.add(value);
  const out: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(value)) {
    out[key] = isRedactedKey(key) ? "[redacted]" : redactValue(item, depth + 1, seen);
  }
  return out;
}

function redactValue(value: unknown, depth: number, seen: WeakSet<object>): unknown {
  if (typeof value === "string") return keep(value);
  if (typeof value === "bigint") return value.toString();
  if (typeof value === "function" || typeof value === "symbol") return `[${typeof value}]`;
  if (value === null || typeof value !== "object") return value;
  if (seen.has(value)) return "[cycle]";
  if (depth >= LOG_DEPTH) return "[deep]";
  if (Array.isArray(value)) {
    seen.add(value);
    return value.slice(0, 50).map((item) => redactValue(item, depth + 1, seen));
  }
  return redactObject(value as Record<string, unknown>, depth, seen);
}

/** A message with the credentials it may carry removed: a bearer token, a key in a query string. */
export function scrub(text: string): string {
  return text
    .replace(/:\/\/[^\/@\s]*@/g, "://[redacted]@")
    .replace(/Basic\s+\S+/gi, "Basic [redacted]")
    .replace(/([?&][\w-]*(?:token|secret|key|password|signature)[\w-]*=)[^&\s]*/gi, "$1[redacted]")
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*/g, "[jwt]")
    .replace(/[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9-]{1,63}(?:\.[A-Za-z0-9-]{1,63}){1,8}/g, "[email]")
    .replace(/Bearer\s+[A-Za-z0-9._~+\/=-]+/gi, "Bearer [redacted]");
}

const clip = (text: string) =>
  text.length > LOG_WIDTH ? text.slice(0, LOG_WIDTH) + "..." : text;

/** What a log line keeps of a text: the text is bounded BEFORE it is scrubbed, so what a client sends costs a fixed amount of work. */
const keep = (text: string) => clip(scrub(text.slice(0, LOG_WIDTH * 4)));

/** What an error is, for a log: its name and its message, scrubbed and clipped. Never for an answer. */
export function describeError(error: unknown): { type: string; message: string } {
  if (error instanceof Error) {
    return { type: keep(String(error.name)), message: keep(String(error.message)) };
  }
  // A database client's error is a plain object with a code and a message.
  if (error !== null && typeof error === "object" && typeof (error as { message?: unknown }).message === "string") {
    const code = (error as { code?: unknown }).code;
    return {
      type: typeof code === "string" && code !== "" ? keep(code) : "object",
      message: keep((error as { message: string }).message),
    };
  }
  let text: string;
  try {
    text = String(error);
  } catch {
    // handled: an error that cannot be printed is described by its kind, never by throwing
    text = "[unprintable]";
  }
  return { type: typeof error, message: keep(text) };
}

/** A request id a client may name: a UUID, or up to 64 characters of letters, digits and . _ : - ; anything else is not echoed. */
const SAFE_REQUEST_ID = /^[A-Za-z0-9._:-]{1,64}$/;

/** The request's own id when it is of a safe shape, else a fresh one: raw client text is never echoed. */
export function requestIdOf(req: Request): string {
  const given = req.headers.get("x-request-id") ?? "";
  return SAFE_REQUEST_ID.test(given) ? given : crypto.randomUUID();
}

/** One structured line: `{level, fn, code, request_id, ...fields}`. */
export function logLine(
  level: Level,
  fn: string,
  code: string,
  fields: Record<string, unknown> = {},
  requestId?: string,
): void {
  let line: string;
  try {
    // the fields first: a field can never override what identifies the line
    line = JSON.stringify({
      ...redactFields(fields),
      level,
      fn,
      code,
      ...(requestId ? { request_id: requestId } : {}),
    });
  } catch {
    // handled: a field that cannot be written never stops the line, nor the answer that logs it
    line = JSON.stringify({ level, fn, code, request_id: requestId, note: "fields not loggable" });
  }
  if (level === "error") console.error(line);
  else if (level === "warn") console.warn(line);
  else if (level === "debug") console.debug(line);
  else console.log(line);
}
