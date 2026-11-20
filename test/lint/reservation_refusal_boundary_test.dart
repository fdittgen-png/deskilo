// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4156 (A1 of #4174) — the booking refusal boundary. The typed refusal is
// pure Dart (it imports nothing but `dart:convert`: no SDK, no Flutter, no
// localisation, no logger, no provider), and the reservation application code
// reads that value, never the transport's error or the words. The SDK type is
// decoded in the data boundary alone; the words are chosen in presentation.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

Iterable<String> _imports(File file) => [
  for (final line in file.readAsLinesSync())
    if (_import.firstMatch(line) case final m?) m.group(1)!,
];

void main() {
  test('the typed refusal is pure Dart', () {
    final value = File(
      'lib/features/reservations/domain/reservation_refusal.dart',
    );
    expect(_imports(value).toList(), ['dart:convert']);
  });

  test('reservation application code imports no SDK, localisation or logger '
      'to read a refusal', () {
    final offenders = [
      for (final file in handWrittenDartFiles(
        'lib/features/reservations/application',
      ))
        for (final uri in _imports(file))
          if (uri.startsWith('package:supabase') || uri.contains('l10n/'))
            '${file.path}: $uri',
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'the application reads ReservationRefused; the SDK error is '
          'decoded in data/, the words are chosen in presentation (#4156)',
    );
  });

  test('the SDK error type is named in the reservation data boundary and '
      'nowhere above it for a booking refusal', () {
    final offenders = [
      for (final dir in [
        'lib/features/reservations/application',
        'lib/features/reservations/domain',
        'lib/features/reservations/presentation',
      ])
        for (final file in handWrittenDartFiles(dir))
          if (file.readAsStringSync().contains('PostgrestException')) file.path,
    ];
    expect(offenders, isEmpty);
  });
}
