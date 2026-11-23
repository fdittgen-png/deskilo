// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4412 -- one envelope for what an edge function answers. A success is its body; a
// refusal is `{error: <stable code>, detail?: <words safe to show>}`; a failure is
// `{error: "internal_error", request_id}` and nothing of the error itself: what went
// wrong is in the log line, found by the request id, never in the answer.

import { CORS } from "./cors.ts";
import { describeError, logLine } from "./log.ts";

const JSON_HEADERS = { ...CORS, "Content-Type": "application/json" };

/** A success: [body] as JSON. */
export function ok(
  body: unknown,
  status = 200,
  headers: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...JSON_HEADERS, ...headers },
  });
}

/** A refusal the caller can act on: a stable [code], the HTTP [status], words safe to show in [detail]. */
export function refuse(
  code: string,
  status: number,
  detail?: string,
  extra: Record<string, unknown> = {},
): Response {
  return ok({ error: code, ...(detail ? { detail } : {}), ...extra }, status);
}

/** What is stable in a failure's answer. */
export const INTERNAL_ERROR = "internal_error";

/** A failure: one log line with the error, and an answer that carries the code and the request id only. */
export function fail(
  error: unknown,
  context: { fn: string; requestId?: string; code?: string; status?: number },
): Response {
  const code = context.code ?? INTERNAL_ERROR;
  logLine("error", context.fn, code, { error: describeError(error) }, context.requestId);
  return ok(
    { error: code, ...(context.requestId ? { request_id: context.requestId } : {}) },
    context.status ?? 500,
  );
}
