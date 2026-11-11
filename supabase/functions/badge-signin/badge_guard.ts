// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3091 — the badge sign-in's cheap guards, pure so they are testable: what
// the scan step may say before a PIN (nothing about the badge), and who the
// caller is for the database's count of scans.

/** A badge UID is lowercase hex without separators; four hex characters
 * are two bytes, which no real tag has (4, 7 and 10-byte UIDs do). */
export const UID_PATTERN = /^[0-9a-f]{8,64}$/;

/** What the scan step hands back: the same for every tag, naming nobody;
 * the form asks for the PIN (GHSA-9525-vh85-5hjg). */
export function identifyAnswer() {
  return { ok: true, step: "identify", display_name: "", has_avatar: false };
}

/** The caller's address as the edge saw it. */
export const callerOf = (req: Request): string =>
  (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() ||
  req.headers.get("cf-connecting-ip") || "unknown";
