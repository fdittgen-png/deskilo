// SPDX-License-Identifier: MIT
//
// The WhatsApp editor on the settings surface (#223): entering a number
// pins the normalization rule (+ + digits) on the exact repository call
// the UI makes; emptying the field clears the share again.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/trace/dev_mode.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';

/// In-memory [DevModeStore]; settings watches it, keep it off the channels.
class _InMemoryDevModeStore implements DevModeStore {
  bool enabled = false;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write(bool enabled) async => this.enabled = enabled;
}

Future<void> pumpSettings(
  WidgetTester tester,
  FakeProfileRepository profile,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(profile: profile),
        devModeStoreProvider.overrideWithValue(_InMemoryDevModeStore()),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'entering a spaced number saves it normalized to + and digits',
      (tester) async {
    final profile = FakeProfileRepository();
    await pumpSettings(tester, profile);

    // Unset yet: the tile reports that nothing is shared.
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Not shared'), findsOneWidget);

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '+33 6 12-34 56 78',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Normalization pinned on the exact value the repository received.
    expect(profile.profiles.single.whatsapp, '+33612345678');
    // The tile now shows the shared number; save is confirmed.
    expect(find.text('+33612345678'), findsOneWidget);
    expect(find.text('Not shared'), findsNothing);
    expect(find.text('WhatsApp number saved'), findsOneWidget);
  });

  testWidgets('emptying the prefilled field clears the shared number',
      (tester) async {
    final profile = FakeProfileRepository(profiles: [
      const Profile(
        id: 'user-1',
        displayName: 'Test User',
        whatsapp: '+33612345678',
      ),
    ]);
    await pumpSettings(tester, profile);

    expect(find.text('+33612345678'), findsOneWidget);

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    // The dialog prefills the current number.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '+33612345678',
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(profile.profiles.single.whatsapp, '');
    expect(find.text('Not shared'), findsOneWidget);
  });

  testWidgets('a failing save surfaces the error and keeps the dialog',
      (tester) async {
    final profile = FakeProfileRepository()..failing = true;
    await pumpSettings(tester, profile);

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '+33612345678');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the WhatsApp number'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
  });
}
