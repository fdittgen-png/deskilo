// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3091 — the badge sign-in's two cheap guards, pure so they are testable:
// what the identify step may say before a PIN, and how often one caller may
// ask it. Neither reveals why a scan was refused.

/** A badge UID is lowercase hex without separators; four hex characters
 * are two bytes, which no real tag has (4, 7 and 10-byte UIDs do). */
export const UID_PATTERN = /^[0-9a-f]{8,64}$/;

/** What the identify step hands back before a PIN: enough for the form to
 * say whose PIN it asks for, and nothing that names the account. */
export function identifyAnswer(
  data: { display_name?: string; has_avatar?: boolean },
) {
  return {
    ok: true,
    step: "identify",
    display_name: data.display_name ?? "",
    has_avatar: data.has_avatar === true,
  };
}

/** At most [max] identify calls per caller within [windowMs]. One edge
 * instance only: a ceiling against a script on one connection, not a
 * distributed one — the per-badge lockout in the database is the other
 * half. */
export class IdentifyLimiter {
  private readonly seen = new Map<string, number[]>();

  constructor(
    private readonly max = 30,
    private readonly windowMs = 60_000,
    private readonly now: () => number = Date.now,
  ) {}

  allow(caller: string): boolean {
    const t = this.now();
    const recent = (this.seen.get(caller) ?? []).filter((x) =>
      t - x < this.windowMs
    );
    if (recent.length >= this.max) {
      this.seen.set(caller, recent);
      return false;
    }
    recent.push(t);
    this.seen.set(caller, recent);
    // Forget callers that went quiet so the map cannot grow without bound.
    if (this.seen.size > 5_000) {
      for (const [key, times] of this.seen) {
        if (t - times[times.length - 1] >= this.windowMs) this.seen.delete(key);
      }
    }
    return true;
  }
}

/** The caller's address as the edge saw it. */
export const callerOf = (req: Request): string =>
  (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() ||
  req.headers.get("cf-connecting-ip") || "unknown";
