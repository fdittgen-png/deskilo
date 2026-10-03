// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2136 — the account avatar that leads back to Me names itself.
//
// Invariant: the Back-to-Me control in a workspace's app bar is announced
// by its tooltip alone; the avatar's initial letter is decoration and is
// not part of its semantics, so a screen reader never says a bare letter
// and the text-contrast audit never measures that letter against the
// whole 48 dp button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'me_app.dart';

void main() {
  testWidgets('Back to Me is announced by its name, not by an initial', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpMeApp(tester, workspace: twoSpaces(serverDefault: 'ws-2'));
    final node = tester.getSemantics(
      find.byKey(const ValueKey('shell-back-to-me')),
    );
    expect(node.label, isEmpty);
    expect(node.tooltip, 'Back to Me');
    semantics.dispose();
  });
}
