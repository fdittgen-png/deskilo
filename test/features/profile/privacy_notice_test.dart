// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1914 — the consent screen shows the notice the SERVER publishes and
// acknowledges exactly that version; the rights and the contact stay
// reachable before anything is accepted; a space's own notice is read
// and acknowledged from Privacy & data; and optional push delivery can
// be turned off on this device, which a restart does not undo.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/push/push_opt_out.dart';
import 'package:deskilo/features/profile/domain/privacy_notice.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/profile/providers/profile_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/open_my_account.dart';

const _operatorNotice = PrivacyNotice(
  version: '2026-10-05',
  controllerName: 'Coworkonti SAS',
  controllerContact: 'privacy@coworkonti.test',
  rightsContact: 'rights@coworkonti.test',
  retention: 'see the matrix',
  recipients: [
    PrivacyRecipient(
      name: 'Own Postgres',
      role: 'processor',
      purpose: 'running the account',
      legalBasis: 'contract',
      region: 'us-east-1',
      transferMechanism: 'scc',
      essential: true,
    ),
    PrivacyRecipient(
      name: 'Firebase Cloud Messaging',
      role: 'processor',
      purpose: 'push delivery',
      legalBasis: 'contract',
      region: 'unknown: Google infrastructure',
      transferMechanism: 'unknown',
      essential: false,
    ),
  ],
);

const _spaceNotice = PrivacyNotice(
  version: 'space-1',
  controllerName: 'The space association',
  controllerContact: 'board@space.test',
  rightsContact: 'board@space.test',
  retention: 'see the matrix',
  recipients: [],
);

class _MemoryOptOut implements PushOptOutStore {
  bool value = false;
  @override
  Future<bool> read() async => value;
  @override
  Future<void> write(bool optedOut) async => value = optedOut;
}

Future<FakeProfileRepository> _pump(
  WidgetTester tester, {
  String? accepted,
  PrivacyNotices notices = const PrivacyNotices(installation: _operatorNotice),
  _MemoryOptOut? optOut,
}) async {
  final profile = FakeProfileRepository(
    profiles: [
      Profile(
        id: 'user-1',
        displayName: 'Test User',
        privacyAcceptedVersion: accepted,
      ),
    ],
    accepted: accepted != null,
  )..notices = notices;
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          profile: profile,
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        ),
        pushOptOutStoreProvider.overrideWithValue(optOut ?? _MemoryOptOut()),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return profile;
}

void main() {
  testWidgets('the consent shows the operator\'s notice and acknowledges '
      'exactly the version the server publishes', (tester) async {
    final profile = await _pump(tester);
    expect(find.text('Who processes your data'), findsOneWidget);
    expect(find.textContaining('Coworkonti SAS'), findsOneWidget);
    expect(find.textContaining('us-east-1'), findsOneWidget);
    expect(find.textContaining('not recorded by the operator'), findsWidgets);
    expect(
      find.textContaining('Optional — you can use the app without it'),
      findsOneWidget,
    );
    expect(find.textContaining('Version 2026-10-05'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('consent-checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consent-accept')));
    await tester.pumpAndSettle();
    expect(profile.acceptedPolicyVersions, ['2026-10-05']);
    expect(find.byKey(const ValueKey('consent-text')), findsNothing);
  });

  testWidgets('an older acknowledgment asks again for the new version, and '
      'the rights stay reachable without accepting', (tester) async {
    await _pump(tester, accepted: '2026-09-20');
    expect(find.byKey(const ValueKey('consent-text')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('consent-rights')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('privacy-who-can-see')), findsOneWidget);
  });

  testWidgets('a space notice is read and acknowledged from Privacy & data', (
    tester,
  ) async {
    final profile = await _pump(
      tester,
      accepted: '2026-10-05',
      notices: const PrivacyNotices(
        installation: _operatorNotice,
        workspace: _spaceNotice,
      ),
    );
    await openMyPrivacy(tester);
    final tile = find.byKey(const ValueKey('privacy-space-notice'));
    await tester.ensureVisible(tile);
    expect(find.text('Not acknowledged yet — read it here.'), findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.textContaining('The space association'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('privacy-space-notice-acknowledge')),
    );
    await tester.pumpAndSettle();
    expect(profile.acknowledgedNotices.single, endsWith(':space-1'));
  });

  testWidgets('push delivery can be turned off on this device, and the '
      'choice is kept', (tester) async {
    final optOut = _MemoryOptOut();
    await _pump(tester, accepted: '2026-10-05', optOut: optOut);
    await openMyPrivacy(tester);
    final toggle = find.byKey(const ValueKey('privacy-push-on-device'));
    await tester.ensureVisible(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(optOut.value, isTrue);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  test('the gate asks for the shipped version only while the server has '
      'none', () async {
    final container = ProviderContainer(
      overrides: [
        privacyNoticesProvider.overrideWith((ref) async => PrivacyNotices.none),
      ],
    );
    addTearDown(container.dispose);
    await container.read(privacyNoticesProvider.future);
    expect(container.read(requiredPrivacyVersionProvider), isNotEmpty);
    final served = ProviderContainer(
      overrides: [
        privacyNoticesProvider.overrideWith(
          (ref) async => const PrivacyNotices(installation: _operatorNotice),
        ),
      ],
    );
    addTearDown(served.dispose);
    await served.read(privacyNoticesProvider.future);
    expect(served.read(requiredPrivacyVersionProvider), '2026-10-05');
  });

  test('every new privacy string exists in all five languages', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.privacyNoticeTitle, isNotEmpty);
      expect(l10n.privacyPushOnDevice, isNotEmpty);
      expect(l10n.privacySpaceNoticeAcknowledge, isNotEmpty);
      expect(l10n.privacyNoticeNotRecorded, isNotEmpty);
    }
  });
}
