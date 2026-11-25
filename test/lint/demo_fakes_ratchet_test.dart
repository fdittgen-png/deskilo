// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4404 -- a Demo fake finds a row by id with `DemoTable.indexOfId` / `byId` and replays a request with `Replay`; it does not write the
// search again (`rows.indexWhere((r) => r.id == id)`) in its own file. The count of the hand-written searches in lib/core/demo is
// recorded and only falls: up is a defect, down is written in the ceiling below in the same change. (146 at the first measure.)
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

/// The hand-written id searches of lib/core/demo today. Never raised.
const int _indexWhereCeiling = 145;

void main() {
  test('the Demo fakes search their rows by id with the shared table, and the hand-written searches only fall (#4404)', () {
    final kind = LiteralKind('indexWhere in a Demo fake', RegExp(r'\bindexWhere\('));
    final perFile = countLiterals(filesUnder(['lib/core/demo']), [kind])[kind.name]!;
    expect(
      total(perFile),
      _indexWhereCeiling,
      reason: ratchetMessage(
        rule: 'Demo fakes (#4404): find a row with DemoTable (lib/core/demo/demo_table.dart)',
        kind: kind.name,
        ceiling: _indexWhereCeiling,
        actual: total(perFile),
        perFile: perFile,
      ),
    );
  });
}
