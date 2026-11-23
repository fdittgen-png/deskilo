// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4412 -- the wrapper of a function's handler: an uncaught error becomes `fail`, one
// log line and the envelope, never a stack or a message in the answer.

import { fail } from "./respond.ts";
import { requestIdOf } from "./log.ts";

/** [handler] given the request and its id; whatever it throws is answered by [fail]. */
export function guard(
  fn: string,
  handler: (req: Request, requestId: string) => Promise<Response> | Response,
): (req: Request) => Promise<Response> {
  return async (req) => {
    const requestId = requestIdOf(req);
    try {
      return await handler(req, requestId);
    } catch (error) {
      return fail(error, { fn, requestId });
    }
  };
}
