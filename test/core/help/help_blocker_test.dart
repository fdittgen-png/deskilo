// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — a mounted HelpBlocker holds the help slot; unmounting frees it.
import 'package:deskilo/core/help/help_arbiter.dart';
import 'package:deskilo/core/help/help_blocker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('blocks while mounted and clears on unmount', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    Widget app({required bool show}) => UncontrolledProviderScope(
      container: c,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: show
            ? const HelpBlocker(id: 'closed-day', child: Text('closed'))
            : const SizedBox(),
      ),
    );

    await tester.pumpWidget(app(show: true));
    await tester.pump();
    expect(c.read(helpSlotProvider), HelpSlot.blocker);

    await tester.pumpWidget(app(show: false));
    await tester.pump();
    expect(c.read(helpSlotProvider), HelpSlot.tips);
  });
}
