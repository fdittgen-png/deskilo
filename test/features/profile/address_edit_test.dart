// SPDX-License-Identifier: 0BSD
//
// The postal-address editor on the settings surface (0060): the address
// is what invoices print in the billed-to block, so saving pins the
// trim on the exact repository call and the tile reflects the value.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';

Future<void> pumpSettings(
  WidgetTester tester,
  FakeProfileRepository profile,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(profile: profile),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('entering an address saves it trimmed through the repository',
      (tester) async {
    final profile = FakeProfileRepository();
    await pumpSettings(tester, profile);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-address')),
      120,
    );
    expect(find.text('No address'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-address')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('address-field')),
      '  12 Rue des Halles\n34120 Pézenas  ',
    );
    await tester.tap(find.byKey(const ValueKey('address-save')));
    await tester.pumpAndSettle();

    expect(
      profile.profiles.single.address,
      '12 Rue des Halles\n34120 Pézenas',
    );
    expect(find.text('Address saved'), findsOneWidget);
    expect(find.text('No address'), findsNothing);
  });

  testWidgets('the dialog prefills the stored address', (tester) async {
    final profile = FakeProfileRepository(profiles: [
      const Profile(
        id: 'user-1',
        displayName: 'Test User',
        address: '5 Place du Marché',
      ),
    ]);
    await pumpSettings(tester, profile);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-address')),
      120,
    );
    await tester.tap(find.byKey(const ValueKey('settings-address')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('address-field')))
          .controller
          ?.text,
      '5 Place du Marché',
    );
  });
}
