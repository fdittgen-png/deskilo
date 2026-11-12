// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3091 — the badge sign-in's cheap guards, pure so they are testable: what
// the scan step may say before a PIN (nothing about the badge), and who the
// caller is for the database's count of scans.

/** A badge UID is lowercase hex without separators; four hex characters
 * are two bytes, which no real tag has (4, 7 and 10-byte UIDs do). */
export const UID_PATTERN = /^[0-9a-f]{8,64}$/;

/** What the scan step hands back: the same for every tag, naming nobody;
 * the form asks for the PIN (GHSA-9525-vh85-5hjg). #3675: on an enrolled
 * kiosk of the tag's own business the database gives the person's name,
 * and only then is it said; this function never looks one up. */
export function identifyAnswer(fromDatabase?: unknown) {
  const name = typeof fromDatabase === "string" ? fromDatabase : "";
  return { ok: true, step: "identify", display_name: name, has_avatar: false };
}

/** The kiosk's credential from `x-deskilo-kiosk: <device id>.<credential>`
 * (#3675), or none. A malformed header is no device, not a refusal: the
 * answer then is exactly the answer without one. */
export const KIOSK_HEADER = "x-deskilo-kiosk";
const KIOSK_PATTERN = /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.([0-9a-f]{64})$/;
export function kioskOf(req: Request): { device_id: string; device_secret: string } | null {
  const m = (req.headers.get(KIOSK_HEADER) ?? "").trim().match(KIOSK_PATTERN);
  return m ? { device_id: m[1], device_secret: m[2] } : null;
}

/** The caller's address as the platform's proxy appended it: the LAST
 * x-forwarded-for hop. Earlier hops are whatever the client claimed. */
export const callerOf = (req: Request): string => {
  const hops = (req.headers.get("x-forwarded-for") ?? "").split(",")
    .map((h) => h.trim()).filter(Boolean);
  return hops.length > 0
    ? hops[hops.length - 1]
    : req.headers.get("cf-connecting-ip") || "";
};
