// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The untyped local save (`fileSaverProvider`) answers a string a screen
// cannot tell apart — a path the person can open, a browser's file name, an
// app-private copy — so every screen reading it says "Saved to" and hopes.
// A delivery goes through `deliverFile` and announces its typed outcome
// (lib/core/files/file_delivery.dart, file_delivery_notice.dart).
//
// A RATCHET: the hand-written lib files that still read the untyped seam
// may only shrink. The Demo scope, which points every outward edge at
// something inert, is the justified allowlist.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _seam = 'fileSaverProvider';

const _allowed = <String>{'lib/core/demo/demo_scope.dart'};

/// Hand-written lib files outside the allowlist that still read the
/// untyped seam. RATCHET: this number only falls.
const _budget = 13;

/// #3613 — the reads of the untyped seam outside lib/core/files and the
/// Demo scope, counted where they happen (`ref.read(fileSaverProvider)`,
/// `ref.watch(fileSaverProvider)`). That seam never asks where: on a
/// desktop each of these still writes straight into Downloads, without the
/// save dialog. Each caller that moves to deliverFile lowers this number.
/// RATCHET: it only falls.
const _readBudget = 17;

final _read = RegExp(r'\.\s*(?:read|watch)\(\s*fileSaverProvider\s*\)');

void main() {
  test('the files reading the untyped local save only shrink', () {
    final naming = [
      for (final f in handWrittenDartFiles('lib'))
        if (!_allowed.contains(f.path) &&
            scanLines([f], (line) => line.contains(_seam)).isNotEmpty)
          f.path,
    ]..sort();
    expect(
      naming.length,
      lessThanOrEqualTo(_budget),
      reason:
          'a new download goes through deliverFile and '
          'announceFileDelivery, which say what the platform achieved; '
          'it does not read $_seam. Now: ${naming.length}:\n'
          '${naming.join('\n')}',
    );
    // A ratchet that cannot fire is deleted: the budget must be tight.
    expect(
      naming.length,
      greaterThanOrEqualTo(_budget),
      reason: 'lower _budget to ${naming.length} (progress is recorded)',
    );
  });

  test('#3613 — the reads of the untyped save, which never asks where on a '
      'desktop, only fall', () {
    var reads = 0;
    final where = <String>[];
    for (final f in handWrittenDartFiles('lib')) {
      if (_allowed.contains(f.path) || f.path.startsWith('lib/core/files/')) {
        continue;
      }
      final n = _read.allMatches(f.readAsStringSync()).length;
      if (n == 0) continue;
      reads += n;
      where.add('${f.path}: $n');
    }
    expect(
      reads,
      lessThanOrEqualTo(_readBudget),
      reason: 'a new save goes through deliverFile, which asks where on a '
          'desktop. Now $reads:\n${where.join('\n')}',
    );
    expect(
      reads,
      greaterThanOrEqualTo(_readBudget),
      reason: 'lower _readBudget to $reads (progress is recorded)',
    );
  });
}
