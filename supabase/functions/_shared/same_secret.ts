// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One comparison of a presented secret with the expected one, for every
// function a database job calls (send-push, settlement-poll).

/** Constant-time equality of two strings. */
export function sameSecret(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}
