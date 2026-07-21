// SPDX-License-Identifier: 0BSD
//
// The status editor on the settings surface (#231): saving pins the
// trim + hard-cap normalization on the exact repository call the UI
// makes; input past the 40-char cap never reaches the repository;
// emptying the field clears the status again.
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
  testWidgets('entering a status saves it trimmed through the repository',
      (tester) async {
    final profile = FakeProfileRepository();
    await pumpSettings(tester, profile);

    // Unset yet: the tile reports no status.
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('No status'), findsOneWidget);

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '  In a call · back at 14:00  ',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Normalization pinned on the exact value the repository received.
    expect(profile.profiles.single.statusText, 'In a call · back at 14:00');
    // The tile now shows the status; save is confirmed.
    expect(find.text('In a call · back at 14:00'), findsOneWidget);
    expect(find.text('No status'), findsNothing);
    expect(find.text('Status saved'), findsOneWidget);
  });

  testWidgets('input past the 40-char cap never reaches the repository',
      (tester) async {
    final profile = FakeProfileRepository();
    await pumpSettings(tester, profile);

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    // 55 chars: the field's maxLength blocks typing past the cap, and
    // normalizeStatusText hard-caps whatever still gets through.
    await tester.enterText(
      find.byType(TextField),
      'x' * (StatusTextRules.maxLength + 15),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      profile.profiles.single.statusText,
      'x' * StatusTextRules.maxLength,
    );
  });

  testWidgets('emptying the prefilled field clears the status',
      (tester) async {
    final profile = FakeProfileRepository(profiles: [
      const Profile(
        id: 'user-1',
        displayName: 'Test User',
        statusText: 'Deep work until noon',
      ),
    ]);
    await pumpSettings(tester, profile);

    expect(find.text('Deep work until noon'), findsOneWidget);

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    // The dialog prefills the current status.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Deep work until noon',
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(profile.profiles.single.statusText, '');
    expect(find.text('No status'), findsOneWidget);
  });

  testWidgets('a failing save surfaces the error and keeps the dialog',
      (tester) async {
    final profile = FakeProfileRepository()..failing = true;
    await pumpSettings(tester, profile);

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'On the terrace');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save the status'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
