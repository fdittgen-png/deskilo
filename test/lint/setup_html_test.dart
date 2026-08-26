// SPDX-License-Identifier: 0BSD
//
// The setup questionnaire NEVER lags the app (#653). `web/setup.html` is
// what a new owner answers BEFORE opening DesKilo, and it is published at
// the URL all five guides link to. A questionnaire that asks about a
// setting the app dropped, omits one the app gained, or pre-ticks a
// module that actually ships OFF sends the owner into a configuration
// that cannot exist.
//
// It drifted twice before this gate existed: it still offered the
// retired "minute bookings within working hours" switch after #634
// replaced it, and it pre-checked seven features that ship disabled.
// Both were found by reading, which is exactly what a gate is for.
//
// So: every parameter the app can configure has to be REACHABLE from
// this file, and the file may not offer anything the app cannot store.
// See docs/AGENT_RULES.md ("The setup questionnaire").
import 'dart:io';

import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File('web/setup.html').readAsStringSync();
  });

  /// The `FEATURES` array literal, as `key -> defaultOn`.
  Map<String, bool> parseFeatures(String source) {
    final start = source.indexOf('const FEATURES=[');
    expect(start, isNot(-1), reason: 'the FEATURES array must exist');
    final end = source.indexOf('\n];', start);
    final block = source.substring(start, end);
    final row = RegExp(r"^ \['([A-Za-z]+)',.*,([01])\],$", multiLine: true);
    return {
      for (final m in row.allMatches(block))
        m.group(1)!: m.group(2) == '1',
    };
  }

  group('features', () {
    test('every WorkspaceFeature is offered, and nothing invented', () {
      final inHtml = parseFeatures(html);
      final inApp = WorkspaceFeature.values.map((f) => f.name).toSet();

      expect(
        inApp.difference(inHtml.keys.toSet()),
        isEmpty,
        reason: 'a feature the app has but the questionnaire never asks '
            'about — add it to the FEATURES array in web/setup.html',
      );
      expect(
        inHtml.keys.toSet().difference(inApp),
        isEmpty,
        reason: 'the questionnaire offers a feature the app does not '
            'have — it was renamed or removed; fix web/setup.html',
      );
    });

    test('every default matches featureManifest — the questionnaire must '
        'not pre-tick a module that ships OFF', () {
      final inHtml = parseFeatures(html);
      final wrong = <String>[];
      for (final entry in featureManifest.entries) {
        final key = entry.key.name;
        final want = entry.value.defaultOn;
        if (inHtml[key] != want) {
          wrong.add('$key: html=${inHtml[key]} registry=$want');
        }
      }
      expect(wrong, isEmpty,
          reason: 'defaults drifted from the registry:\n${wrong.join('\n')}');
    });
  });

  group('booking rules', () {
    // Wire keys, not labels: the questionnaire's XML is what carries an
    // answer into the app, so the key is the contract. Labels are prose
    // and may be worded freely.
    test('every booking_rules key the client writes is carried by the XML',
        () {
      const keys = <String>[
        BookingPolicies.allowPastBookingsKey,
        BookingPolicies.adminCheckOutKey,
        BookingPolicies.outsideHoursModeKey,
        BookingPolicies.simultaneousReservationsKey,
        BookingPolicies.advanceHorizonDaysKey,
        BookingPolicies.minDurationMinutesKey,
        BookingPolicies.maxDurationMinutesKey,
      ];
      for (final key in keys) {
        // snake_case key -> kebab-case XML attribute.
        final attr = key.replaceAll('_', '-');
        expect(html, contains(attr),
            reason: 'web/setup.html neither asks nor exports "$key". A '
                'booking rule the app can set must be answerable here.');
      }
    });

    test('the retired grid_within_hours switch is never WRITTEN again', () {
      // #634 folded it into outside_hours_mode. Reading it on import is
      // the documented legacy mapping and stays; offering it as a
      // question, or writing it into the export, does not.
      expect(html, isNot(contains('grid-within-hours="')),
          reason: 'the export must not write the retired key');
      // Reading the old key to MIGRATE a previously exported file is
      // required (it mirrors the server's own legacy mapping), so the
      // ban is on ASKING: no checkbox, no label, no option row.
      expect(html, isNot(contains("['gridHours',")),
          reason: 'the questionnaire must not still ask the retired '
              'question — #634 replaced it with outside_hours_mode');
      expect(html, contains("gridHours"),
          reason: 'but it MUST still read the legacy key on import, or '
              'an old questionnaire silently reads as "charged" instead '
              'of "walkup_only"');
    });

    test('all four outside-hours modes are offered', () {
      for (final mode in OutsideHoursMode.values) {
        expect(html, contains("'${mode.wire}'"),
            reason: 'the questionnaire must offer ${mode.wire} — the '
                'owner picks between all four, not a subset');
      }
    });
  });

  group('granularity', () {
    test('every BookingGranularity wire value is offered', () {
      // Read from the GRAN constant so a renamed granularity fails here
      // rather than silently disappearing from the questionnaire.
      final start = html.indexOf('const GRAN=[');
      expect(start, isNot(-1));
      final gran = html.substring(start, html.indexOf('];', start));
      for (final value in [
        'half_day',
        'full_day',
        'hours',
        'minutes_60',
        'minutes_30',
        'minutes_15',
        'minutes_5',
      ]) {
        expect(gran, contains("'$value'"),
            reason: '$value must be selectable in the questionnaire');
      }
    });
  });
}
