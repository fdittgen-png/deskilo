// SPDX-License-Identifier: 0BSD
//
// #1274 — what the server says a year's public holidays would do.
//
// The GENERATOR is SQL (`public_holidays(country, year)`), because
// `apply_workspace_template` runs in the database and cannot call Dart.
// A second computus here would be a second source of truth, and the two
// would disagree on an Easter eventually. So this layer parses the
// server's answer and nothing more.
//
// Pure Dart: no Flutter, no l10n — the CLI imports this layer.
library;

/// One day the server offered, as it described it.
typedef HolidayDay = ({
  DateTime day,

  /// The key the server returns — `easterMonday`, `armistice`. The app
  /// looks up a localized name by this, so the name never travels.
  String key,

  /// Its month already carries an invoice, so it will NOT be created:
  /// a closure day there would change what that month included, and so
  /// somebody's bill.
  bool locked,

  /// A closure day already exists on this date.
  bool present,
});

/// The server's answer to a preview or an apply.
class HolidayGeneration {
  const HolidayGeneration({
    required this.days,
    required this.lockedMonths,
    required this.created,
  });

  final List<HolidayDay> days;

  /// The months refused, named — `['2026-07']`. Never silent.
  final List<String> lockedMonths;

  /// Rows written. Always 0 for a preview.
  final int created;

  /// What an apply would still create: neither locked nor already there.
  Iterable<HolidayDay> get creatable =>
      days.where((d) => !d.locked && !d.present);

  static const empty =
      HolidayGeneration(days: [], lockedMonths: [], created: 0);
}

/// Parses `generate_closure_days`' jsonb. Unknown fields are ignored so
/// an older client survives a newer server.
HolidayGeneration holidayGenerationFromJson(Map<String, dynamic> json) {
  final rawDays = json['days'];
  return HolidayGeneration(
    days: [
      for (final entry in rawDays is List ? rawDays : const <Object?>[])
        if (entry is Map<String, dynamic> && entry['day'] is String)
          (
            day: DateTime.parse(entry['day'] as String),
            key: '${entry['key'] ?? ''}',
            locked: entry['locked'] == true,
            present: entry['present'] == true,
          ),
    ],
    lockedMonths: [
      for (final m in json['locked_months'] is List
          ? json['locked_months'] as List<Object?>
          : const <Object?>[])
        '$m',
    ],
    created: switch (json['created']) {
      final int n => n,
      final String s => int.tryParse(s) ?? 0,
      _ => 0,
    },
  );
}
