// SPDX-License-Identifier: 0BSD
//
// #886 — the personal-information editor on the settings surface: what
// a person types here is what every document prints in the billed-to
// block and the envelope window, so saving pins the normalized value on
// the exact repository call, the preview shows the postal standard, and
// the tile reflects the value afterwards.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
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

Future<void> openForm(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('settings-personal-info')),
    120,
  );
  // The tile's centre is its help dot (which opens the guide); the
  // leading icon is the tile itself.
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('settings-personal-info')),
      matching: find.byIcon(Icons.contact_mail_outlined),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String field, String text) async {
  await tester.enterText(find.byKey(ValueKey('personal-info-$field')), text);
  await tester.pump();
}

void main() {
  testWidgets(
    'the form previews the postal standard and saves the normalized value',
    (tester) async {
      final profile = FakeProfileRepository();
      await pumpSettings(tester, profile);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-personal-info')),
        120,
      );
      expect(find.text('Not filled in yet'), findsOneWidget);
      await openForm(tester);

      await type(tester, 'first-name', ' Guilhem ');
      await type(tester, 'last-name', 'martin');
      await type(tester, 'company', 'SASU KaloA');
      await type(tester, 'street', '209 rue Jean Bart, Immeuble AGORA 1B');
      await type(tester, 'postal-code', '31670');
      await type(tester, 'city', 'Labège');
      await type(tester, 'phone', ' +33 6 00 00 00 00 ');

      // The preview IS the envelope window: the addressee, then the
      // block. #912 — the company is the addressee, the person moves
      // under it.
      final preview = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('personal-info-preview')),
          matching: find.byType(Text),
        ),
      );
      expect(
        preview.data,
        'SASU KaloA\n'
        'Guilhem MARTIN\n209 rue Jean Bart, Immeuble AGORA 1B\n31670 LABÈGE',
      );

      await tester.tap(find.byKey(const ValueKey('personal-info-save')));
      await tester.pumpAndSettle();

      final saved = profile.lastPersonalInfo;
      expect(saved, isNotNull);
      expect(saved!.firstName, 'Guilhem', reason: 'trimmed');
      expect(
        saved.lastName,
        'martin',
        reason: 'stored as typed; documents capitalise',
      );
      expect(saved.phone, '+33 6 00 00 00 00');
      expect(
        saved.countryCode,
        isNotEmpty,
        reason: 'the workspace country is proposed when none was chosen',
      );
      expect(find.text('Personal information saved'), findsOneWidget);

      // Back on Settings, the tile summarises what documents will print.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-personal-info')),
        120,
      );
      expect(find.text('Not filled in yet'), findsNothing);
      // #912 — the company leads, the person follows it.
      expect(
        find.textContaining('SASU KaloA · Guilhem MARTIN'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the form prefills the stored identity', (tester) async {
    final profile = FakeProfileRepository(
      profiles: [
        const Profile(
          id: 'user-1',
          displayName: 'Test User',
          identity: PersonalInfo(
            firstName: 'Anne',
            lastName: 'Dupont',
            street: '5 Place du Marché',
            countryCode: 'DE',
          ),
        ),
      ],
    );
    await pumpSettings(tester, profile);
    await openForm(tester);

    String text(String field) => tester
        .widget<TextField>(find.byKey(ValueKey('personal-info-$field')))
        .controller!
        .text;
    expect(text('first-name'), 'Anne');
    expect(text('last-name'), 'Dupont');
    expect(text('street'), '5 Place du Marché');
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('personal-info-country')),
          )
          .initialValue,
      'DE',
    );
  });
}
