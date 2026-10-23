// SPDX-License-Identifier: AGPL-3.0-or-later
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
import 'package:flutter_test/flutter_test.dart';
import 'lint_sources.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File('web/setup.html').readAsStringSync();
  });

  // #2923 — the feature list, its defaults, REQUIRES and AVAILABLE_IN are
  // no longer copied into the page: they arrive generated in
  // web/setup_catalogue.js (SETUP_REGISTRY), drift-gated by
  // setup_l10n_test, so there is no copy left here to pin.
  group('dependencies', () {
    test('processes are presentation only: the XML carries no process key',
        () {
      // The page groups by process (setup_catalogue.js) and the import
      // reads features; a process element or attribute in the export
      // would be a second payload nothing consumes.
      expect(html, isNot(contains('<process')));
      expect(html, isNot(contains('process=')));
      expect(html, isNot(contains('subprocess=')));
    });
  });

  group('booking rules', () {
    // Wire keys, not labels: the questionnaire's XML is what carries an
    // answer into the app, so the key is the contract. Labels are prose
    // and may be worded freely.
    //
    // #1559 — and this test is a PRESENCE check, not a behaviour one. It
    // greps the kebab-case spelling ANYWHERE in the HTML, and the page
    // writes every one of these names into `<setup>`, the extension the
    // app ignores on purpose. So it stayed green the whole time
    // `work_start_minutes`, `half_boundary_minutes`, `work_end_minutes`,
    // `half_day_hours`, `full_day_hours`, `allow_past_bookings`,
    // `admin_check_out` and `simultaneous_reservations` reached the app
    // as nothing at all. A name found in the file proves the question is
    // asked; it cannot prove the answer arrives. What the app ends up
    // with is pinned where it can be: setup_page_contract_test.dart runs
    // the real page, parses its real export and reads `booking_rules`
    // with WorkHours.fromRules and BookingPolicies.fromRules.
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

  group('help links', () {
    /// Every anchor id the chapter files declare, user and setup guide.
    Set<String> guideAnchors() {
      final comment = RegExp(r'<!--\s*anchor:\s*([a-z][a-z0-9.-]*)\s*-->');
      return {
        for (final dir in ['docs/guide/user', 'docs/guide/setup'])
          for (final file in filesWithExtension(dir, '.en.md'))
            for (final m in comment.allMatches(file.readAsStringSync()))
              m.group(1)!,
      };
    }

    test('every help link lands on a section of the guide site', () {
      // The guide site gives each section its anchor as the element id, so
      // a key that names no anchor opens the page at the top.
      final start = html.indexOf('const HELP={');
      expect(start, isNot(-1), reason: 'the HELP table must exist');
      final block = html.substring(start, html.indexOf('\n};', start));
      final anchors = RegExp(r"^ [A-Za-z_]+:\['[A-Za-z]+','([^']+)'\],$",
              multiLine: true)
          .allMatches(block)
          .map((m) => m.group(1)!)
          .toList();
      expect(anchors, hasLength(greaterThan(30)));
      final known = guideAnchors();
      for (final anchor in anchors) {
        expect(known, contains(anchor),
            reason: 'HELP links to #$anchor, which no guide chapter declares');
      }
      expect(html, contains("guideUrl('user.start.questionnaire')"));
      expect(known, contains('user.start.questionnaire'));
      expect(html, isNot(contains('github.com/fdittgen-png/deskilo/wiki')),
          reason: 'the user and setup guides live on the guide site');
    });
  });
}
