// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3286 — repeated help symbols on one screen are told apart: each one's
// tooltip and accessible name says which topic it opens the guide for.
import 'package:deskilo/core/help/help_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('two help dots have two different names', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const Scaffold(
        body: Column(children: [HelpDot('Opening hours'), HelpDot('Pricing')]),
      ),
    );
    await tester.pump();
    String name(String topic) =>
        tester.getSemantics(find.byKey(ValueKey('help-dot-$topic'))).tooltip;
    expect(name('Opening hours'), 'Open the guide: Opening hours');
    expect(name('Pricing'), 'Open the guide: Pricing');
    handle.dispose();
  });
}
