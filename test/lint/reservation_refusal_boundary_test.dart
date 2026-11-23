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
    expect(_imports(value).toList(), [
      'dart:convert',
      '../../../core/codes/dk_code.dart', // pure constants (#4417)
    ]);
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

  // #4315 / #4316 -- the regressions of #4156: a booking write left outside the one conversion
  // (the host's check-in and cancel, the kiosk's badge identification) reached the screen as the
  // transport's error and showed the generic sentence. Every booking write of the data files is
  // made inside `asReservationRefusal` (directly, or inside the repository's `_traced`, which
  // wraps it).
  test('every booking write of the reservation data files is made inside the one conversion', () {
    const writes = [
      'create_reservation_once',
      'check_in_reservation',
      'check_out_reservation',
      'cancel_reservation',
      'update_reservation',
      'kiosk_identify',
      'kiosk_act',
      'create_series',
      'convert_to_series',
      'cancel_series',
      'update_series',
    ];
    final call = RegExp("rpc<[^>]*>\\(\\s*'(${writes.join('|')})'");
    final outside = <String>[];
    for (final file in handWrittenDartFiles('lib/features/reservations/data')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final text = lines.skip(i).take(2).join(' ');
        final m = call.firstMatch(text);
        if (m == null || !lines[i].contains('rpc<')) continue;
        // the method the call is in: from its declaration down to the call
        var start = i;
        while (start > 0 && !RegExp(r'^\s*(@override|Future<|Stream<|void\s)').hasMatch(lines[start])) {
          start--;
        }
        final before = lines.sublist(start, i + 1).join('\n');
        if (!before.contains('asReservationRefusal(') && !before.contains('_traced(')) {
          outside.add('${file.path}:${i + 1}: ${m.group(1)}');
        }
      }
    }
    expect(outside, isEmpty, reason: 'a booking write outside the conversion shows the generic sentence');
  });

  test('the host\'s commands, whose name is a variable, are made inside the conversion too', () {
    final source = File('lib/features/reservations/data/host_my_reservation_actions.dart').readAsStringSync();
    expect(source, contains('asReservationRefusal('));
    expect(source.indexOf('asReservationRefusal('), lessThan(source.indexOf('host.client.rpc')));
  });
}
