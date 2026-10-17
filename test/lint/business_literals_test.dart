// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2484 (S1 of #2483) -- a business value is a SETTING (the registry,
// migration 0428), not a constant. This ratchet counts the business
// literals still in the code, by NAMED list (a file and the exact pattern of
// the value), so a partial win is visible and a new literal is a defect. It
// is not a regex over everything: a size, a duration of an animation or a
// protocol constant is not a business value and is never listed.
//
// Each entry names what the value means, where it lives and how many
// literals of it the file holds today. The count may only go down; when it
// does, lower the ceiling (the failure says so). A checkpoint (S2..S5) that
// moves a value to the registry deletes its entry. An entry that turns out
// not to be a business value moves to `_allowed` WITH its reason.
//
// The same shape as `tax_literals_test.dart` (VAT has its own ratchet).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

const _rule = 'business_literals (#2483)';

typedef _Tracked = ({
  String what,
  String file,
  String pattern,
  int ceiling,
  String movesIn,
});

/// The business values the epic measured (the sample, not a census).
const _tracked = <_Tracked>[
  (what: 'the country a device with no locale falls back to', file: 'lib/core/locale/device_locale.dart',
   pattern: r"\?\? 'FR'", ceiling: 1, movesIn: 'S5'),
  // #2572 -- the rest of S2..S5, Dart side.
  (what: 'the one UI snap of the booking grid (15 minutes)', file: 'lib/features/workspace/domain/booking_granularity.dart',
   pattern: r'defaultStepMinutes = \d+', ceiling: 1, movesIn: 'never (allowed)'),
  (what: 'currency fallback of the format controller', file: 'lib/core/i18n/format_controller.dart',
   pattern: r"currencyCode \?\? 'EUR'", ceiling: 1, movesIn: 'S5'),
  (what: 'locale and currency of the format controller seed', file: 'lib/core/i18n/format_controller.dart',
   pattern: r"locale: 'en_US', currencyCode: 'EUR'", ceiling: 1, movesIn: 'S5'),
  (what: 'AppFormat.fallback locale and currency', file: 'lib/core/i18n/app_format.dart',
   pattern: r"locale: 'en_US', currencyCode: 'EUR'", ceiling: 1, movesIn: 'S5'),
  (what: 'the currency code before one is installed', file: 'lib/core/i18n/workspace_currency.dart',
   pattern: r"\?\? 'EUR'", ceiling: 1, movesIn: 'S5'),
  (what: 'currency fallback of the letter data maps', file: 'lib/features/money/domain/report_data_letters.dart',
   pattern: r"currencyCode \?\? 'EUR'", ceiling: 3, movesIn: 'S5'),
  (what: 'geocoder endpoint default', file: 'lib/features/directory/data/photon_directory_geocoder.dart',
   pattern: r"defaultValue: 'https://", ceiling: 1, movesIn: 'S5'),
  (what: 'map tile endpoint default', file: 'lib/features/directory/presentation/directory_map.dart',
   pattern: r"defaultValue: 'https://", ceiling: 1, movesIn: 'S5'),
  // Reviewed as NOT business values (see _allowed): still counted, so a new
  // one next to them is a failing test.
  (what: 'presence heartbeat interval (protocol constant)', file: 'lib/core/presence/presence_rules.dart',
   pattern: r'heartbeatInterval = Duration\(minutes: \d+\)', ceiling: 1, movesIn: 'never (allowed)'),
  (what: 'language to country heuristic', file: 'lib/core/locale/device_locale.dart',
   pattern: r"'[a-z]{2}' => '[A-Z]{2}'", ceiling: 7, movesIn: 'never (allowed)'),
  (what: 'export format currency of the Sage file', file: 'lib/features/money/domain/sage.dart',
   pattern: r"'EUR'", ceiling: 2, movesIn: 'never (allowed)'),
  (what: 'export format currency of the FEC file', file: 'lib/features/money/domain/fec.dart',
   pattern: r"'EUR'", ceiling: 2, movesIn: 'never (allowed)'),
  (what: 'export format currency of the DATEV file', file: 'lib/features/money/domain/datev.dart',
   pattern: r"'EUR'", ceiling: 2, movesIn: 'never (allowed)'),
  // The column defaults of 0051 (invitation, 14 days) and 0272 (confirmation, 5
  // minutes) left the ratchet with 0451 (S2): create_invitation now states
  // expires_at from the setting, and the confirmation default calls
  // mcp_confirmation_expires_at().
];

typedef _TrackedSql = ({
  String what,
  String function,
  String pattern,
  int ceiling,
  String movesIn,
});

/// The same, counted in the LIVE definition of an SQL function (the latest
/// `create or replace function public.<name>(` in supabase/migrations). Every
/// S2 and S4 value is SQL-only and lives here.
const _trackedSql = <_TrackedSql>[
  (what: 'MCP notice read-state purge (90 days)', function: 'mark_instance_notice_read',
   pattern: r"interval '\d+ days'", ceiling: 1, movesIn: 'S4'),
  (what: 'MCP notice read-state purge (90 days)', function: 'instance_notify_operators',
   pattern: r"interval '\d+ days'", ceiling: 1, movesIn: 'S4'),
  (what: 'readiness "recent export" window (90 days)', function: 'workspace_readiness',
   pattern: r"interval '\d+ days'", ceiling: 1, movesIn: 'S4'),
  (what: 'VIES evidence freshness (90 days)', function: 'member_vies_verified',
   pattern: r"interval '\d+ days'", ceiling: 1, movesIn: 'S4'),
  (what: 'MCP read range (31 days, guardrail)', function: 'mcp_read_v1',
   pattern: r"interval '31 days'", ceiling: 1, movesIn: 'S4'),
  (what: 'calendar range (400 days, guardrail) and its text', function: 'calendar_items',
   pattern: r'400 days', ceiling: 2, movesIn: 'S4'),
  (what: 'capacity KPI range (400 days, guardrail) and its text', function: 'kpi_seat_capacity',
   pattern: r'400 days', ceiling: 2, movesIn: 'S4'),
  (what: 'finance KPI range (23 months, guardrail)', function: 'kpi_finance_summary',
   pattern: r"interval '23 months'", ceiling: 1, movesIn: 'S4'),
];

/// Entries reviewed as NOT business values, keyed by `file::what`, with the
/// reason. An entry here with no matching tracked row fails; the row stays
/// counted, so a new literal beside it is still a failing test.
const _allowed = <String, String>{
  'lib/features/workspace/domain/booking_granularity.dart::the one UI snap of the booking grid (15 minutes)':
      'the UI fallback of day-based granularity and of the grid-less modes; the step itself is booking_rules.granularity (#2486 S3)',
  'lib/core/presence/presence_rules.dart::presence heartbeat interval (protocol constant)':
      'the beat is the client protocol; the online window beside it is the setting (S3)',
  'lib/core/locale/device_locale.dart::language to country heuristic':
      'a guess from the device language for the first screen, not a choice anybody makes; nothing legal derives from it',
  'lib/features/money/domain/sage.dart::export format currency of the Sage file':
      'the Sage import format fixes the currency code it writes',
  'lib/features/money/domain/fec.dart::export format currency of the FEC file':
      'the FEC format fixes the currency code it writes',
  'lib/features/money/domain/datev.dart::export format currency of the DATEV file':
      'the DATEV format fixes the currency code it writes',
};

/// The currency fallback: `'EUR'` written in lib/ (S5 moves the fallback to
/// the workspace country's currency). Counted over lib/, minus generated
/// files, l10n output and the demo dataset (fixtures, not defaults).
const _eurCeiling = 63; // measured 2026-10-14 (#2479: the threshold rows carry their currency)

int _count(String file, String pattern) {
  final f = File(file);
  if (!f.existsSync()) return -1;
  final comment = file.endsWith('.sql') ? '--' : '//';
  return RegExp(pattern)
      .allMatches(codeLines(f, comment: comment).join('\n'))
      .length;
}

void main() {
  for (final t in _tracked) {
    test('${t.what} (${t.file}) stays at its ceiling until ${t.movesIn} moves it', () {
      final actual = _count(t.file, t.pattern);
      expect(actual, isNot(-1), reason: '${t.file} no longer exists: delete the entry');
      expect(
        actual,
        t.ceiling,
        reason: ratchetMessage(
          rule: _rule,
          kind: t.what,
          ceiling: t.ceiling,
          actual: actual,
          perFile: {t.file: actual},
        ),
      );
    });
  }

  for (final t in _trackedSql) {
    test('${t.what} (${t.function}) stays at its ceiling until ${t.movesIn} moves it', () {
      final actual =
          RegExp(t.pattern).allMatches(latestFunctionDefinition(t.function)).length;
      expect(
        actual,
        t.ceiling,
        reason: ratchetMessage(
          rule: _rule,
          kind: '${t.what} in public.${t.function}',
          ceiling: t.ceiling,
          actual: actual,
          perFile: {'public.${t.function}': actual},
        ),
      );
    });
  }

  test('an allowed entry still names a tracked value (the list cannot rot)', () {
    for (final key in _allowed.keys) {
      expect(
        _tracked.any((t) => '${t.file}::${t.what}' == key),
        isTrue,
        reason: '$_rule: "$key" is allowed but no longer tracked: delete it',
      );
      expect(_allowed[key]!.trim(), isNotEmpty);
    }
  });

  test('the currency fallback literal in lib/ only goes down', () {
    final files = filesUnder(['lib']).where((f) =>
        !f.path.endsWith('.g.dart') &&
        !f.path.contains('/l10n/') &&
        !f.path.contains('lib/core/demo/'));
    final per = countLiterals(files, [LiteralKind("'EUR'", RegExp(r"'EUR'"))]);
    final perFile = per["'EUR'"]!;
    final actual = total(perFile);
    expect(actual, _eurCeiling,
        reason: ratchetMessage(
            rule: _rule, kind: "the currency literal 'EUR'", ceiling: _eurCeiling, actual: actual, perFile: perFile));
  });
}
