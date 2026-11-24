// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4412 -- a provider fake that answers at once, as `fetch`: the fake stays a
// plain function (no `async` without an `await`, which `deno lint` refuses).

/** [answer] as a `fetch`: each call resolves to what [answer] returns for it. */
export const asFetch = (
  answer: (
    input: string | URL | Request,
    init?: RequestInit,
  ) => Response | Promise<Response>,
): typeof fetch =>
  ((input: string | URL | Request, init?: RequestInit) =>
    Promise.resolve(answer(input, init))) as typeof fetch;
