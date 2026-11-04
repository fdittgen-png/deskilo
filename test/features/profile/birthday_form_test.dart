// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3278 — the birthday on the personal-information form: it says who can read
// it, takes a day from a calendar bounded by what the table accepts, saves
// with the rest of the form (its own write, reported on its own), clears, and
// says plainly when only the rest was saved.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/open_my_account.dart';

Future<void> _openForm(
  WidgetTester tester,
  FakeProfileRepository profile,
) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(profile: profile),
      child: const DeskiloApp(),
    ),
  );
  await _settle(tester);
  await openMyAccount(tester);
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('settings-personal-info')),
    120,
  );
  final icon = find.descendant(
    of: find.byKey(const ValueKey('settings-personal-info')),
    matching: find.byIcon(Icons.contact_mail_outlined),
  );
  await _settle(tester);
  await tester.ensureVisible(icon);
  await _settle(tester);
  await tester.tap(icon);
  await _settle(tester);
}

Finder _key(String k) => find.byKey(ValueKey(k));

/// Two bounded frames: enough for a sheet, a dialog or a route to finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(_key('personal-info-save'));
  await tester.tap(_key('personal-info-save'));
  await _settle(tester);
}

FakeProfileRepository _repo({DateTime? birthday}) => FakeProfileRepository(
  profiles: [
    Profile(
      id: 'user-1',
      displayName: 'Test User',
      birthday: birthday,
      identity: const PersonalInfo(firstName: 'Ada', lastName: 'Lovelace'),
    ),
  ],
);

void main() {
  testWidgets('the form asks for the birthday and says who can read it', (
    tester,
  ) async {
    await _openForm(tester, _repo());
    await tester.ensureVisible(_key('personal-info-birthday'));
    expect(find.text('Birthday'), findsOneWidget);
    expect(find.text('Choose a date'), findsOneWidget);
    expect(
      find.textContaining('Someone who only issues invoices cannot'),
      findsOneWidget,
    );
    expect(_key('personal-info-birthday-clear'), findsNothing);
  });

  testWidgets('a day chosen on the calendar is saved with the rest and shown '
      'again', (tester) async {
    final profile = _repo();
    await _openForm(tester, profile);
    await tester.ensureVisible(_key('personal-info-birthday'));
    await tester.tap(_key('personal-info-birthday'));
    await _settle(tester);
    // The calendar opens thirty years back; OK takes that day.
    await tester.tap(find.text('OK'));
    await _settle(tester);
    expect(_key('personal-info-birthday-clear'), findsOneWidget);
    await _save(tester);
    final saved = profile.profiles.single.birthday;
    expect(saved, isNotNull);
    expect(saved!.isBefore(kTestNow), isTrue);
  });

  testWidgets('an existing birthday is prefilled and can be removed', (
    tester,
  ) async {
    final profile = _repo(birthday: DateTime(1990, 4, 12));
    await _openForm(tester, profile);
    await tester.ensureVisible(_key('personal-info-birthday'));
    expect(find.textContaining('1990'), findsOneWidget);
    await tester.tap(_key('personal-info-birthday-clear'));
    await _settle(tester);
    expect(find.text('Choose a date'), findsOneWidget);
    await _save(tester);
    expect(profile.profiles.single.birthday, isNull);
  });

  testWidgets('when only the birthday fails, the rest is saved and the '
      'sentence says so', (tester) async {
    final profile = _repo();
    await _openForm(tester, profile);
    await tester.ensureVisible(_key('personal-info-birthday'));
    await tester.tap(_key('personal-info-birthday'));
    await _settle(tester);
    await tester.tap(find.text('OK'));
    await _settle(tester);
    profile.failing = true;
    await _save(tester);
    expect(profile.lastPersonalInfo, isNotNull, reason: 'the rest was saved');
    expect(
      find.text('Your details were saved, but the birthday could not be.'),
      findsOneWidget,
    );
    expect(profile.profiles.single.birthday, isNull);
  });
}
