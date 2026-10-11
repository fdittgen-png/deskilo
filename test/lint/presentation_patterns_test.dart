// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2388 — one way to open a sheet (`showAppSheet`, lib/core/ui/app_sheet.dart)
// and one debouncer (`Debouncer`, lib/core/ui/debouncer.dart). A screen that
// calls `showModalBottomSheet` itself, or keeps a `Timer? _debounce` of its
// own, has stepped around the decision both of them hold.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Sheets still opened directly: files an open branch was changing when
/// the rest moved (#2388); the count only goes down.
const _directSheetBudget = 2;

void main() {
  final files = handWrittenDartFiles('lib').toList();

  test('sheets open through showAppSheet (ratchet)', () {
    final direct = RegExp(r'\bshowModalBottomSheet\s*(<|\()');
    final hits = scanLines(
      files.where((f) => !f.path.endsWith('core/ui/app_sheet.dart')),
      direct.hasMatch,
    );
    expect(
      hits.length,
      lessThanOrEqualTo(_directSheetBudget),
      reason: 'open the sheet with showAppSheet:\n${hits.join('\n')}',
    );
    expect(
      hits.length,
      _directSheetBudget,
      reason: 'fewer direct sheets: lower _directSheetBudget to ${hits.length}',
    );
  });

  test('no hand-rolled debounce timer', () {
    final hits = scanLines(
      files,
      (line) => RegExp(r'Timer\?\s+_debounce\b').hasMatch(line),
    );
    expect(
      hits,
      isEmpty,
      reason: 'use Debouncer (lib/core/ui/debouncer.dart):\n${hits.join('\n')}',
    );
  });
}
