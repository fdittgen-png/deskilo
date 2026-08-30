// SPDX-License-Identifier: 0BSD
//
// #751 — the GDPR consent gate: an account that has not accepted the
// current policy version sees the consent screen and nothing else;
// ticking and accepting records the version on the account and lets
// the app through; an accepted account never sees it; the text stays
// readable from Settings → Privacy & data with the acceptance date.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/privacy/privacy_policy.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeProfileRepository> pump(WidgetTester tester,
    {bool accepted = false, String? version}) async {
  final profile = FakeProfileRepository(
    profiles: [
      Profile(
        id: 'user-1',
        displayName: 'Test User',
        privacyAcceptedVersion: version,
      ),
    ],
    accepted: accepted,
  );
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(
      profile: profile,
      floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
    ),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  return profile;
}

void main() {
  testWidgets('an account that never accepted lands on the consent, whole '
      'text shown, and cannot leave without ticking', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('consent-text')), findsOneWidget);
    expect(find.text('What DesKilo processes'), findsOneWidget);
    expect(find.text('Your rights'), findsOneWidget);
    expect(find.textContaining('Version $kPrivacyPolicyVersion'), findsOneWidget);
    // The app behind it is not reachable.
    expect(find.text('Reserve'), findsNothing);
    final accept = tester.widget<FilledButton>(
        find.byKey(const ValueKey('consent-accept')));
    expect(accept.onPressed, isNull);
  });

  testWidgets('ticking and accepting records the version and opens the app',
      (tester) async {
    final profile = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('consent-checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consent-accept')));
    await tester.pumpAndSettle();
    expect(profile.acceptedPolicyVersions, [kPrivacyPolicyVersion]);
    expect(find.byKey(const ValueKey('consent-text')), findsNothing);
    // The shell (with its always-visible privacy shield) is now there.
    expect(find.byKey(const ValueKey('shell-privacy')), findsOneWidget);
  });

  testWidgets('no profile row at all still gates (fails closed)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(
        profile: FakeProfileRepository(profiles: const [], accepted: false),
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      ),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('consent-text')), findsOneWidget);
  });

  testWidgets('an older accepted version asks again', (tester) async {
    await pump(tester, version: '2000-01-01');
    expect(find.byKey(const ValueKey('consent-text')), findsOneWidget);
  });

  testWidgets('an accepted account goes straight in and can review the text '
      'with its date from Privacy & data', (tester) async {
    await pump(tester, accepted: true);
    expect(find.byKey(const ValueKey('consent-text')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('shell-privacy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('privacy-consent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('consent-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('consent-accepted-on')), findsOneWidget);
    // Review mode: no checkbox, no accept button.
    expect(find.byKey(const ValueKey('consent-accept')), findsNothing);
  });
}
