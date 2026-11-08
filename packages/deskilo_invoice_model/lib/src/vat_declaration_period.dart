// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — how often the workspace files its VAT return. Stored as
// `invoice_legal.vat_declaration_period` beside the tax point, carried
// by the configuration export and the setup questionnaire; the
// declarations screen offers only periods of this length.

/// The length of one VAT filing period.
enum VatDeclarationPeriod {
  /// Monthly (FR réel normal, DE Voranmeldung above the threshold).
  month,

  /// Quarterly — the default when a workspace never chose.
  quarter,

  /// Annual (FR réel simplifié CA12, a yearly return elsewhere).
  annual;

  /// What a workspace that never chose files, the questionnaire's default.
  static const VatDeclarationPeriod fallback = quarter;

  /// Null for anything else — a workspace that never chose.
  static VatDeclarationPeriod? fromWire(Object? raw) =>
      raw is String ? values.asNameMap()[raw] : null;
}

/// One filing period of [period]'s length.
typedef VatFilingPeriod = ({DateTime start, DateTime end});

/// The filing periods of [period]'s length, the one holding [now] first,
/// walked backwards: twelve months, eight quarters or four years.
List<VatFilingPeriod> vatFilingPeriodsOf(
  DateTime now,
  VatDeclarationPeriod period,
) => switch (period) {
  VatDeclarationPeriod.month => [
    for (var i = 0; i < 12; i++)
      (
        start: DateTime(now.year, now.month - i),
        end: DateTime(now.year, now.month - i + 1, 0),
      ),
  ],
  VatDeclarationPeriod.quarter => [
    for (var i = 0; i < 8; i++)
      (
        start: DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1 - 3 * i),
        end: DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 4 - 3 * i, 0),
      ),
  ],
  VatDeclarationPeriod.annual => [
    for (var i = 0; i < 4; i++)
      (start: DateTime(now.year - i), end: DateTime(now.year - i, 12, 31)),
  ],
};
