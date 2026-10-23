// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2862 — the configuration PDF's lines that are formatting rather than
// gathering: the open days, the closures, the working hours as hh:mm, the
// VAT rates in force and the sites, each in the reader's locale.
import 'package:intl/intl.dart';

import '../../../core/time/work_hours.dart';
import '../domain/closure_day.dart';
import '../domain/site.dart';

/// The open days by name, Monday first ([openWeekdays] in ISO 1..7).
String configOpenDays(String? locale, Iterable<int> openWeekdays) {
  // ISO weekday → its name through a known Monday.
  final format = DateFormat.EEEE(locale);
  return (openWeekdays.toList()..sort())
      .map((d) => format.format(DateTime(2026, 6, d)))
      .join(', ');
}

/// One line per closure: its day, and its reason when it has one.
List<String> configClosures(String? locale, List<ClosureDay> closures) {
  final format = DateFormat.yMMMd(locale);
  return [
    for (final c in closures)
      if (c.reason.trim().isEmpty)
        format.format(c.day.toLocal())
      else
        '${format.format(c.day.toLocal())} — ${c.reason}',
  ];
}

/// The day's two halves as hh:mm: `08:00–12:30 · 12:30–17:00`.
String configWorkingHours(WorkHours hours) {
  String hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
  return '${hhmm(hours.startMinutes)}–${hhmm(hours.halfBoundaryMinutes)} · '
      '${hhmm(hours.halfBoundaryMinutes)}–${hhmm(hours.endMinutes)}';
}

/// One line per VAT rate: its label and its percentage.
List<String> configVatRates(
  String? locale,
  Iterable<({String label, double percent})> rates,
) {
  final percent = NumberFormat.decimalPattern(locale);
  return [for (final r in rates) '${r.label} — ${percent.format(r.percent)} %'];
}

/// One line per site: its name and its address.
List<String> configSites(List<Site> sites) => [
  for (final s in sites)
    [
      s.name,
      [
        s.street,
        [s.postalCode, s.city].where((p) => p.isNotEmpty).join(' '),
      ].where((p) => p.isNotEmpty).join(', '),
    ].where((p) => p.isNotEmpty).join(' — '),
];
