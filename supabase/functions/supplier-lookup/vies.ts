// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The VIES adapter (#2863): the EU's VAT Information Exchange System,
// asked through its public REST endpoint. VIES validates a VAT number and
// returns the name and address when the member state discloses them —
// some answer `---` for both — so the answer is read into the neutral
// contract with two separate verdicts: whether a record came back, and
// whether the number is valid. Nothing here is a secret: the endpoint is
// public, and the requester is never named, so no consultation number is
// asked for (that is the invoice flow's job, vies-check).

import type { Adapter, LookupRequest, LookupResult } from "./contract.ts";

const VIES_URL =
  "https://ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number";

/** How long VIES gets before the question counts as timed out. */
export const VIES_TIMEOUT_MS = 15000;

/** The most of VIES's answer that is read; a longer body is malformed. */
export const VIES_MAX_RESPONSE_BYTES = 64 * 1024;

/** What a member state writes when it discloses nothing. */
const UNDISCLOSED = /^-*$/;

/** A postal code then a city, on the last line of an address. */
const POSTAL_LINE = /^([0-9]{4}\s?[A-Z]{2}|[0-9]{4,6})\s+(.+)$/;

type Fields = Record<string, string>;

/**
 * Splits the one address string VIES returns into the supplier's fields.
 * Only a last line that reads as "postal code, city" is taken apart; any
 * other shape stays whole in `street`, so nothing is guessed — the person
 * moves the parts in the review step.
 */
export function splitAddress(address: string): Fields {
  const lines = address
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0 && !UNDISCLOSED.test(l));
  if (lines.length === 0) return {};
  const last = lines[lines.length - 1];
  const postal = POSTAL_LINE.exec(last);
  if (lines.length >= 2 && postal) {
    return {
      street: lines.slice(0, -1).join(", "),
      postal_code: postal[1],
      city: postal[2],
    };
  }
  return { street: lines.join(", ") };
}

/** The outcome VIES's own error code stands for. */
function failureFor(error: string): LookupResult["retrieval"] {
  switch (error) {
    case "INVALID_INPUT":
    case "INVALID_REQUESTER_INFO":
      return "invalid_input";
    case "MS_MAX_CONCURRENT_REQ":
    case "GLOBAL_MAX_CONCURRENT_REQ":
    case "IP_BLOCKED":
    case "VAT_BLOCKED":
      return "throttled";
    case "TIMEOUT":
      return "timeout";
    default:
      return "unavailable";
  }
}

/** Reads a body of at most `limit` bytes; null when it is longer. */
async function readBounded(
  response: Response,
  limit: number,
): Promise<string | null> {
  const declared = Number(response.headers.get("content-length") ?? "0");
  if (declared > limit) return null;
  const text = await response.text();
  return text.length > limit ? null : text;
}

/** One VIES question; never throws — an outage is an outcome. */
export async function askVies(
  request: LookupRequest,
  fetcher: typeof fetch = fetch,
  now: () => Date = () => new Date(),
): Promise<LookupResult> {
  const lookedUpAt = now().toISOString();
  const base = { provider: "vies", looked_up_at: lookedUpAt };
  const failure = (
    retrieval: LookupResult["retrieval"],
    detail = "",
  ): LookupResult => ({
    ...base,
    retrieval,
    validation: retrieval === "invalid_input" ? "not_validated" : "unavailable",
    fields: {},
    reference: "",
    detail,
  });
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), VIES_TIMEOUT_MS);
  try {
    const response = await fetcher(VIES_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({
        countryCode: request.country_code,
        vatNumber: request.identifier,
      }),
      signal: controller.signal,
    });
    const text = await readBounded(response, VIES_MAX_RESPONSE_BYTES);
    if (text === null) return failure("malformed", "response too large");
    let answer: Record<string, unknown>;
    try {
      answer = JSON.parse(text);
    } catch {
      return failure("malformed", `HTTP ${response.status}`);
    }
    if (!response.ok || typeof answer?.valid !== "boolean") {
      const wrappers = answer?.errorWrappers;
      const error = Array.isArray(wrappers) && wrappers.length > 0
        ? String((wrappers[0] as Record<string, unknown>)?.error ?? "")
        : "";
      if (!error && !response.ok) {
        return failure(response.status === 429 ? "throttled" : "unavailable", `HTTP ${response.status}`);
      }
      return failure(error ? failureFor(error) : "malformed", error);
    }
    if (!answer.valid) {
      return {
        ...base,
        retrieval: "not_found",
        validation: "invalid",
        fields: {},
        reference: String(answer.requestIdentifier ?? ""),
        detail: "",
      };
    }
    const fields: Fields = { country_code: request.country_code };
    const name = typeof answer.name === "string" ? answer.name.trim() : "";
    if (name && !UNDISCLOSED.test(name)) fields.name = name;
    const address = typeof answer.address === "string" ? answer.address : "";
    Object.assign(fields, splitAddress(address));
    const disclosed = Object.keys(fields).some((k) => k !== "country_code");
    return {
      ...base,
      retrieval: disclosed ? "retrieved" : "not_returned",
      validation: "validated",
      fields,
      reference: String(answer.requestIdentifier ?? ""),
      detail: "",
    };
  } catch (error) {
    const aborted = error instanceof DOMException && error.name === "AbortError";
    // The failure class is logged, never the identifier that was asked.
    console.warn(`supplier-lookup: VIES ${aborted ? "timed out" : "did not answer"}`);
    return failure(aborted ? "timeout" : "unavailable", aborted ? "timeout" : "no answer");
  } finally {
    clearTimeout(timer);
  }
}

/** What VIES can do: a VAT number of an EU member state, by identifier. */
export const viesAdapter: Adapter = {
  id: "vies",
  kinds: ["vat"],
  modes: ["identifier"],
  lookup: askVies,
};
