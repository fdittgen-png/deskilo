// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4419 — a bound more than one function holds, written once. Each has no
// SQL twin (test/lint/mirrored_bounds_test.dart lists the ones that do):
// they bound a request or a call, which only the function sees.

/** The most a mail request body may weigh: the ids and the base64 PDF Resend
 * accepts (resend.ts bounds the PDF at 8 MB of base64). */
export const MAIL_BODY_MAX_BYTES = 8_100_000; // not-mirrored: the mail provider's attachment size, not a stored value

/** The longest one call to a payment provider may take before it counts as
 * unreachable. */
export const PROVIDER_CALL_TIMEOUT_MS = 15_000; // not-mirrored: a network wait of the function, not a stored value
