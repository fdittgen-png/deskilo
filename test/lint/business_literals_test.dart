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
  (what: 'check-in opens 15 minutes before the start', file: 'lib/features/reservations/domain/reservation.dart',
   pattern: r'checkInLeeway = Duration\(minutes: \d+\)', ceiling: 1, movesIn: 'S3'),
  (what: 'check-in reminder lookahead and lead time', file: 'lib/features/reservations/domain/check_in_reminders.dart',
   pattern: r'const Duration\((?:days|minutes): \d+\)', ceiling: 2, movesIn: 'S3'),
  (what: 'walk-up booking window and floor', file: 'lib/features/reservations/domain/walk_up_window.dart',
   pattern: r'const Duration\((?:hours|minutes): \d+\)', ceiling: 2, movesIn: 'S3'),
  (what: 'booking intent ledger cap', file: 'lib/features/reservations/domain/booking_intent.dart',
   pattern: r'static const int cap = \d+', ceiling: 1, movesIn: 'S3'),
  (what: 'maximum advance days of a subscription run', file: 'lib/features/money/domain/billing_rules.dart',
   pattern: r'maxAdvanceDays = \d+', ceiling: 1, movesIn: 'S3'),
  (what: 'presence: how long a heartbeat keeps someone online', file: 'lib/core/presence/presence_rules.dart',
   pattern: r'onlineWindow = Duration\(minutes: \d+\)', ceiling: 1, movesIn: 'S3'),
  (what: 'the country a device with no locale falls back to', file: 'lib/core/locale/device_locale.dart',
   pattern: r"\?\? 'FR'", ceiling: 1, movesIn: 'S5'),
];

/// Entries reviewed as NOT business values, keyed by `file::what`, with the
/// reason. Empty today; an entry here with no matching tracked row fails.
const _allowed = <String, String>{};

/// The currency fallback: `'EUR'` written in lib/ (S5 moves the fallback to
/// the workspace country's currency). Counted over lib/, minus generated
/// files, l10n output and the demo dataset (fixtures, not defaults).
const _eurCeiling = 64; // measured 2026-10-14 (#2479: the threshold rows carry their currency)

int _count(String file, String pattern) {
  final f = File(file);
  if (!f.existsSync()) return -1;
  return RegExp(pattern).allMatches(codeLines(f).join('\n')).length;
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
