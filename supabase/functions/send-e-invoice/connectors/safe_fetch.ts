// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3090 — the one fetch every provider call goes through. A workspace
// administrator types the endpoint of the generic upload (and the base URLs
// of the named platforms), so the function must not be a way to reach what
// the administrator cannot: only `https:`, never a loopback, private,
// link-local, metadata or carrier-grade address — checked on the literal
// and on every address the name resolves to — and never a redirect, which
// would walk past the check.

import type { Fetch } from "./common.ts";

/** What a refused destination or redirect throws; connectors turn it into
 * a failed outcome and the client sees only the fixed key. */
export class DestinationRefused extends Error {
  constructor(readonly key: "destination_not_allowed" | "redirect_refused") {
    super(key);
  }
}

export type Resolver = (host: string) => Promise<string[]>;

/** A and AAAA records of [host]. A name that does not resolve is refused. */
export const resolveHost: Resolver = async (host) => {
  const found: string[] = [];
  for (const type of ["A", "AAAA"] as const) {
    try {
      found.push(...await Deno.resolveDns(host, type));
    } catch {
      // No record of this type.
    }
  }
  return found;
};

function ipv4(address: string): number[] | null {
  const parts = address.split(".");
  if (parts.length !== 4) return null;
  const octets = parts.map((p) => (/^\d{1,3}$/.test(p) ? Number(p) : NaN));
  return octets.every((o) => o >= 0 && o <= 255) ? octets : null;
}

/** Whether [address] (IPv4 or IPv6 literal) may be called: false for every
 * range that is not the public internet. */
export function isPublicAddress(address: string): boolean {
  const v4 = ipv4(address);
  if (v4) {
    const [a, b, c] = v4;
    if (a === 0 || a === 10 || a === 127) return false;
    if (a === 169 && b === 254) return false; // link-local, cloud metadata
    if (a === 172 && b >= 16 && b <= 31) return false;
    if (a === 192 && b === 168) return false;
    if (a === 100 && b >= 64 && b <= 127) return false; // carrier-grade NAT
    if (a === 192 && b === 0 && c === 0) return false;
    if (a === 198 && (b === 18 || b === 19)) return false;
    if (a >= 224) return false; // multicast, reserved, broadcast
    return true;
  }
  const v6 = address.toLowerCase().replace(/^\[|\]$/g, "");
  if (!v6.includes(":")) return false; // not an address at all
  if (v6 === "::" || v6 === "::1") return false;
  const mapped = v6.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped) return isPublicAddress(mapped[1]);
  // The URL parser writes a mapped IPv4 address as two hex groups.
  const hex = v6.match(/^::ffff:([0-9a-f]{1,4}):([0-9a-f]{1,4})$/);
  if (hex) {
    const hi = parseInt(hex[1], 16);
    const lo = parseInt(hex[2], 16);
    return isPublicAddress(`${hi >> 8}.${hi & 255}.${lo >> 8}.${lo & 255}`);
  }
  if (/^f[cd]/.test(v6)) return false; // unique local fc00::/7
  if (/^fe[89ab]/.test(v6)) return false; // link-local fe80::/10
  if (/^ff/.test(v6)) return false; // multicast
  return true;
}

/** Refuses [raw] unless it is an https URL whose host is public. */
export async function assertPublicUrl(
  raw: string,
  resolve: Resolver = resolveHost,
): Promise<void> {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new DestinationRefused("destination_not_allowed");
  }
  if (url.protocol !== "https:") {
    throw new DestinationRefused("destination_not_allowed");
  }
  const host = url.hostname.replace(/^\[|\]$/g, "");
  const lower = host.toLowerCase();
  if (
    lower === "localhost" || lower.endsWith(".localhost") ||
    lower.endsWith(".local") || lower.endsWith(".internal")
  ) {
    throw new DestinationRefused("destination_not_allowed");
  }
  if (ipv4(host) || host.includes(":")) {
    if (!isPublicAddress(host)) {
      throw new DestinationRefused("destination_not_allowed");
    }
    return;
  }
  const addresses = await resolve(host);
  if (addresses.length === 0 || !addresses.every(isPublicAddress)) {
    throw new DestinationRefused("destination_not_allowed");
  }
}

/** [inner] behind the destination check; a redirect is refused, not
 * followed. */
export function safeFetch(
  inner: Fetch = fetch,
  resolve: Resolver = resolveHost,
): Fetch {
  return async (input, init) => {
    await assertPublicUrl(
      input instanceof Request ? input.url : String(input),
      resolve,
    );
    const res = await inner(input, { ...init, redirect: "manual" });
    if (res.status >= 300 && res.status < 400) {
      throw new DestinationRefused("redirect_refused");
    }
    return res;
  };
}

/** What the client may read of an outcome (#3090): the provider's own words
 * stay in the server log and the transmission row, never in the answer. */
export function clientDetail(
  status: "accepted" | "rejected" | "failed" | string,
  detail: string,
): string {
  if (status === "accepted") return "";
  if (detail === "destination_not_allowed" || detail === "redirect_refused") {
    return detail;
  }
  return status === "rejected" ? "provider_rejected" : "provider_unreachable";
}
