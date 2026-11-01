// SPDX-License-Identifier: AGPL-3.0-or-later

import 'country_seed.g.dart';

/// How a country's banks identify an account — the shape the payment
/// instructions take (#711).
enum BankingScheme {
  /// IBAN (+ BIC): the euro area, Switzerland, Norway and the UK's IBAN
  /// form. One field, checksummed.
  sepa,

  /// Sort code + account number.
  uk,

  /// ABA routing number + account number.
  us,

  /// Transit number + institution number + account number.
  ca,

  /// #2360 — Switzerland: an IBAN, and a QR-IBAN for the QR-bill's QRR
  /// reference.
  ch,
}

/// One country the app knows how to bill in (spec §3).
class Country {
  const Country(
    this.code,
    this.currencyCode,
    this.defaultTimezone, {
    this.scheme = BankingScheme.sepa,
  });

  /// ISO 3166-1 alpha-2.
  final String code;

  /// The ISO 4217 code a workspace here bills in by default.
  final String currencyCode;

  /// The IANA zone a workspace here keeps time in by default — the
  /// capital's. A country spanning several (US, CA, AU) gets the one
  /// most of its coworkings sit in; the owner picks another if not.
  final String defaultTimezone;

  final BankingScheme scheme;
}

/// The countries a workspace may be in (#711 -- 32, aligned with the VAT
/// catalogue so every country the app can DECLARE tax for is a country
/// it can be BASED in).
///
/// #2488 -- the catalogue is reference data: the `country` rows of the tax
/// reference store, edited by the platform administrator. This class keeps
/// its API and reads them: the installed rows once the app has read the
/// store ([install]), else the compile-time copy of the seed
/// (`bundledCountries`), so a form never waits on the network and a server
/// that is away still answers. A country added in the store appears in the
/// workspace creation form and sets its currency and time zone.
abstract final class CountryCatalog {
  static List<Country>? _installed;

  /// The countries in catalogue order.
  static List<Country> get countries => _installed ?? bundledCountries;

  /// Replaces the bundled copy with the store's rows. An empty list is
  /// refused (a store that answers nothing must not empty every form).
  static void install(Iterable<Country> rows) {
    final list = List<Country>.unmodifiable(rows);
    if (list.isNotEmpty) _installed = list;
  }

  /// Back to the bundled copy (tests).
  static void reset() => _installed = null;

  /// The catalog entry for [code]; an unknown code (old data, hand-typed
  /// import) reads as the catalogue's first-listed fallback, France, rather
  /// than crashing a form.
  static Country byCode(String code) => countries.firstWhere(
        (c) => c.code == code.toUpperCase(),
        orElse: () => countries.firstWhere(
          (c) => c.code == 'FR',
          orElse: () => bundledCountries.firstWhere((c) => c.code == 'FR'),
        ),
      );

  static bool isKnown(String code) =>
      countries.any((c) => c.code == code.toUpperCase());
}
