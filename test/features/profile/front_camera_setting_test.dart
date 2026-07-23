// SPDX-License-Identifier: 0BSD
//
// The front-camera switch in Settings → Preferences: on by default,
// toggling writes the device-local preference the badge scanner reads.
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  testWidgets(
      'the switch is on by default; toggling stores the back-camera '
      'choice', (tester) async {
    final store = InMemoryFrontCameraStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(frontCamera: store),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('settings-front-camera'));
    await tester.scrollUntilVisible(
      tile,
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(tile).value,
      isTrue,
    );

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(store.value, isFalse);
  });
}
