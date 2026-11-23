// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4412 -- one structured log line per event of an edge function: the function, the
// request, the code and the level, with what must never reach a log left out. A
// failure is one line, never a sentence with a payload in it.

export type Level = "debug" | "info" | "warn" | "error";

/** Fields whose value is a secret or a person's data: their value is replaced. */
const REDACTED_KEY =
  /authorization|token|secret|password|passwd|api[_-]?key|credential|cookie|signature|iban|private|bearer/i;

/** The longest a logged string stays: a log line is a pointer, not the payload. */
export const LOG_WIDTH = 300;

/** [fields] with the secret ones replaced and long strings clipped. One level of nesting is read. */
export function redactFields(
  fields: Record<string, unknown>,
): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    if (REDACTED_KEY.test(key)) {
      out[key] = "[redacted]";
    } else if (typeof value === "string") {
      out[key] = clip(scrub(value));
    } else if (
      value !== null && typeof value === "object" && !Array.isArray(value)
    ) {
      out[key] = redactFields(value as Record<string, unknown>);
    } else {
      out[key] = value;
    }
  }
  return out;
}

/** A message with the credentials it may carry removed: a bearer token, a key in a query string. */
export function scrub(text: string): string {
  return text
    .replace(/Bearer\s+[A-Za-z0-9._~+\/=-]+/gi, "Bearer [redacted]")
    .replace(
      /([?&](?:api[_-]?key|token|secret|key|password|signature)=)[^&\s]+/gi,
      "$1[redacted]",
    );
}

const clip = (text: string) =>
  text.length > LOG_WIDTH ? text.slice(0, LOG_WIDTH) + "..." : text;

/** What an error is, for a log: its name and its message, scrubbed and clipped. Never for an answer. */
export function describeError(error: unknown): { name: string; message: string } {
  if (error instanceof Error) {
    return { name: error.name, message: clip(scrub(error.message)) };
  }
  return { name: typeof error, message: clip(scrub(String(error))) };
}

/** The request's own id when the platform gave one, else a fresh one. */
export function requestIdOf(req: Request): string {
  return req.headers.get("x-request-id") ?? crypto.randomUUID();
}

/** One structured line: `{level, fn, code, request_id, ...fields}`. */
export function logLine(
  level: Level,
  fn: string,
  code: string,
  fields: Record<string, unknown> = {},
  requestId?: string,
): void {
  const line = JSON.stringify({
    level,
    fn,
    code,
    ...(requestId ? { request_id: requestId } : {}),
    ...redactFields(fields),
  });
  if (level === "error") console.error(line);
  else if (level === "warn") console.warn(line);
  else if (level === "debug") console.debug(line);
  else console.log(line);
}
