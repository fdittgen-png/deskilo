// SPDX-License-Identifier: AGPL-3.0-or-later

/// #1240 — personal data never reaches the diagnostic log.
///
/// The trace is device-local and goes nowhere on its own, which is the
/// whole privacy position. But it EXISTS to be shared: the Developer
/// screen offers it as a file so somebody can send it to support, and
/// the export stamps it with the app version, the workspace id and the
/// member id so the reader knows which report it answers.
///
/// So the one moment it leaves the device is the moment it must carry
/// nothing the reader did not ask for. `no_silent_catch_test` requires
/// every catch to trace, which means the volume of server error text
/// reaching this file is a deliberate maximum — and a Postgrest message
/// quotes the row it refused.
///
/// The masks below keep the SHAPE, because a redacted log still has to
/// be debuggable: an address that reads `<email>` tells you a mail
/// address was involved, which is usually the fact that matters.
library;

/// Patterns replaced in every trace line, in order.
///
/// Order is load-bearing: the IBAN rule would otherwise eat the digits
/// of a long card number, and the token rule would eat an e-mail's
/// domain.
final List<({RegExp pattern, String mask})> _rules = [
  // A bearer token or an API key: long, opaque, and the one thing here
  // that is a live credential rather than a fact about a person.
  (
    pattern: RegExp(r'\b(?:eyJ|sb_|sk_|pk_|rk_)[A-Za-z0-9._\-]{12,}'),
    mask: '<token>',
  ),
  (
    pattern: RegExp(r'\bBearer\s+[A-Za-z0-9._\-]{8,}', caseSensitive: false),
    mask: 'Bearer <token>',
  ),
  // An e-mail address. Masked whole rather than to its domain: the
  // domain of a small coworking space identifies the person nearly as
  // well as the address.
  (
    pattern: RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b'),
    mask: '<email>',
  ),
  // An IBAN — two letters, two check digits, then up to thirty.
  (
    pattern: RegExp(r'\b[A-Z]{2}\d{2}[A-Z0-9]{10,30}\b'),
    mask: '<iban>',
  ),
  // A card-shaped number: 13–19 digits, optionally grouped.
  (
    pattern: RegExp(r'\b(?:\d[ -]?){13,19}\b'),
    mask: '<card>',
  ),
  // An international phone number. Deliberately requires the +, so a
  // plain run of digits — a count, an amount in cents, a duration — is
  // left alone.
  (
    pattern: RegExp(r'\+\d[\d\s().-]{7,}\d'),
    mask: '<phone>',
  ),
];

/// [line] with anything personal or credential-shaped masked.
///
/// Cheap enough to run on every entry as it is formatted: a handful of
/// regexes over a line that is already being built.
String redactTraceLine(String line) {
  var out = line;
  for (final rule in _rules) {
    out = out.replaceAll(rule.pattern, rule.mask);
  }
  return out;
}
