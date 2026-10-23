// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The provider-neutral contract of a company lookup (#2863), the same
// words the app reads (lib/features/money/domain/company_lookup.dart).
// An adapter speaks one registry and answers in these terms; the handler
// never sees a registry's own response shape.

/** The outcomes of retrieving a record, apart from validating a number. */
export type Retrieval =
  | "retrieved"
  | "not_returned"
  | "not_found"
  | "invalid_input"
  | "unsupported"
  | "timeout"
  | "throttled"
  | "unavailable"
  | "malformed";

/** What the registry said about the identifier itself. */
export type Validation =
  | "validated"
  | "invalid"
  | "not_validated"
  | "unavailable";

export type LookupRequest = {
  /** The registry's own country code (`EL` for Greece). */
  country_code: string;
  /** Letters and digits only, upper case. */
  identifier: string;
  kind: "vat" | "registration";
  mode: "identifier" | "name";
};

export type LookupResult = {
  provider: string;
  looked_up_at: string;
  retrieval: Retrieval;
  validation: Validation;
  /** Only the fields the registry returned: name, street, postal_code,
   * city, country_code. */
  fields: Record<string, string>;
  /** The registry's own reference for the answer, when it gave one. */
  reference: string;
  /** The registry's own words for a failure; never shown as such. */
  detail: string;
};

/** One registry. A national register joins by implementing this. */
export type Adapter = {
  id: string;
  kinds: LookupRequest["kind"][];
  modes: LookupRequest["mode"][];
  lookup: (
    request: LookupRequest,
    fetcher?: typeof fetch,
    now?: () => Date,
  ) => Promise<LookupResult>;
};
