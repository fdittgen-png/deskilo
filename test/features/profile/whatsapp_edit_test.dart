// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The WhatsApp editor on the settings surface (#223): entering a number
// pins what the repository receives (#3650: the validated international
// form, and what was typed beside it); emptying the field clears the share
// again; a number that cannot be validated is refused in words, and one
// stored before numbers were checked asks to be confirmed.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/open_my_account.dart';

Future<void> pumpSettings(
  WidgetTester tester,
  FakeProfileRepository profile,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(profile: profile),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await openMyAccount(tester); // #1823: My account is in Me
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
      find.byKey(const ValueKey('whatsapp-number')),
      '+33 6 12-34 56 78',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Normalization pinned on the exact value the repository received.
    expect(profile.profiles.single.whatsapp, '+33612345678');
    // The tile now shows the shared number; save is confirmed.
    expect(find.text('+33 6 12 34 56 78'), findsOneWidget);
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

    expect(find.text('+33 6 12 34 56 78'), findsOneWidget);

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    // The dialog prefills the current number.
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('whatsapp-number'))).controller?.text,
      '+33612345678',
    );
    await tester.enterText(find.byKey(const ValueKey('whatsapp-number')), '');
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
    await tester.enterText(find.byKey(const ValueKey('whatsapp-number')), '+33612345678');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the WhatsApp number'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('whatsapp-number')), findsOneWidget);
  });

  testWidgets('a national number is read in the owner\'s country and kept as typed',
      (tester) async {
    final profile = FakeProfileRepository();
    profile.profiles[0] = profile.profiles[0].copyWith(
      identity: const PersonalInfo(countryCode: 'FR'),
    );
    await pumpSettings(tester, profile);
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('whatsapp-number')), '06 12 34 56 78');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(profile.profiles.single.whatsapp, '+33612345678');
    expect(profile.profiles.single.whatsappTyped, '06 12 34 56 78');
  });

  testWidgets('a number that cannot be validated is refused in words, not saved',
      (tester) async {
    final profile = FakeProfileRepository();
    await pumpSettings(tester, profile);
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('whatsapp-number')), '06 12 34 56 78');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the country of this number, or type it with its + code.'), findsOneWidget);
    expect(profile.profiles.single.whatsapp, '');
  });

  testWidgets('a number stored before numbers were checked asks to be confirmed',
      (tester) async {
    final profile = FakeProfileRepository();
    profile.profiles[0] = profile.profiles[0].copyWith(whatsapp: '+0612345678');
    await pumpSettings(tester, profile);
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('whatsapp-needs-correction')), findsOneWidget);
    expect(find.text('+0612345678'), findsWidgets);
  });
}
