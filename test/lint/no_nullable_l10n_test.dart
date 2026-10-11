// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2388 — strings come from `context.l10n` (lib/core/l10n/context_l10n.dart),
// which is never null: without delegates it reads the English ARB. The
// nullable lookup made every string be written twice — `l10n?.key ??
// 'English'` — and the English in Dart drifted from the ARB. A nullable
// lookup (`AppLocalizations.of(context)`, `l10n?.`) fails here; the count
// of the ones not yet moved only goes down.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Nullable lookups left in hand-written lib/ (6 557 `l10n?.` before the
/// sweep; these sit in files an open branch was changing at the time,
/// three of them added by the VAT work merged meanwhile).
const _budget = 551;

void main() {
  test('no nullable l10n lookup (ratchet)', () {
    final nullable = RegExp(r'\bl10n\?\.|AppLocalizations\.of\(');
    final hits = scanLines(
      handWrittenDartFiles('lib')
          .where((f) => !f.path.endsWith('core/l10n/context_l10n.dart')),
      nullable.hasMatch,
    ).where((h) => !RegExp(r':\d+: ///').hasMatch(h)).toList();
    expect(
      hits.length,
      lessThanOrEqualTo(_budget),
      reason:
          'read strings through context.l10n (never null):\n'
          '${hits.join('\n')}',
    );
    expect(
      hits.length,
      _budget,
      reason:
          'fewer nullable lookups than the budget: lower _budget to '
          '${hits.length}',
    );
  });
}
