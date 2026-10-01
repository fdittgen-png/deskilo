// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1829 — the instance owner is visible to everyone, and only the owner
// delegates: the Settings entry names them, the sheet shows how to reach
// them, and the delegate controls exist for the owner alone. A delegate is
// shown as one, a new instance's creator can take ownership, and a server
// that has not said shows nothing.
import 'package:deskilo/core/demo/data/instance_repository.dart';
import 'package:deskilo/features/workspace/domain/instance_responsibles.dart';
import 'package:deskilo/features/workspace/presentation/widgets/instance_owner_tile.dart';
import 'package:deskilo/features/workspace/providers/instance_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = InstanceResponsible(
  name: 'Ada OWNER',
  email: 'ada@example.org',
);
const _delegateForOwner = InstanceResponsible(
  name: 'Ben DELEGATE',
  email: 'ben@example.org',
  userId: 'user-ben',
);
const _delegateForOthers = InstanceResponsible(
  name: 'Ben DELEGATE',
  email: 'ben@example.org',
);

Future<FakeInstanceRepository> pumpTile(
  WidgetTester tester,
  InstanceResponsibles state,
) async {
  final repo = FakeInstanceRepository(state: state);
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [instanceRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: InstanceOwnerTile()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('instance-owner-tile')));
  await tester.pumpAndSettle();
}

void main() {
  group('reading the server answer', () {
    test('the owner sees account ids; roles and people are read as sent', () {
      final r = InstanceResponsibles.fromJson({
        'installation_id': 'inst-1',
        'you': 'owner',
        'claimable': false,
        'owners': [
          {'name': 'Ada OWNER', 'email': 'ada@example.org'},
        ],
        'delegates': [
          {
            'user_id': 'user-ben',
            'name': 'Ben',
            'email': 'ben@example.org',
            'since': '2026-09-29T10:00:00Z',
          },
        ],
      });
      expect(r.isOwner, isTrue);
      expect(r.owners.single.email, 'ada@example.org');
      expect(r.delegates.single.userId, 'user-ben');
      expect(r.delegates.single.since, isNotNull);
    });

    test('a delegate is an operator but not the owner', () {
      final r = InstanceResponsibles.fromJson({
        'installation_id': 'inst-1',
        'you': 'delegate',
      });
      expect(r.isOperator, isTrue);
      expect(r.isOwner, isFalse);
    });

    test('anything unreadable is unavailable; nameless entries are dropped', () {
      expect(InstanceResponsibles.fromJson('nope').installationId, isEmpty);
      final r = InstanceResponsibles.fromJson({
        'installation_id': 'inst-1',
        'owners': [
          {'name': 'No mail', 'email': ''},
          {'email': 'only@example.org'},
        ],
      });
      expect(r.owners.single.name, 'only@example.org');
    });

    test('a delegation answer keeps its reason', () {
      expect(
        DelegationOutcome.fromJson({'status': 'refused', 'reason': 'no_account'}),
        DelegationOutcome.noAccount,
      );
      expect(
        DelegationOutcome.fromJson({'status': 'refused', 'reason': 'unconfirmed'}),
        DelegationOutcome.unconfirmed,
      );
      expect(
        DelegationOutcome.fromJson({'status': 'delegated'}),
        DelegationOutcome.delegated,
      );
      expect(DelegationOutcome.fromJson(null), DelegationOutcome.unavailable);
    });
  });

  group('the Settings entry and its sheet', () {
    testWidgets('a server that has not said shows nothing', (tester) async {
      await pumpTile(tester, InstanceResponsibles.unavailable);
      expect(find.byKey(const ValueKey('instance-owner-tile')), findsNothing);
    });

    testWidgets('a member sees the owner and how to reach them, nothing to change', (
      tester,
    ) async {
      await pumpTile(
        tester,
        const InstanceResponsibles(
          installationId: 'inst-1',
          owners: [_owner],
          delegates: [_delegateForOthers],
        ),
      );
      expect(find.text('Ada OWNER'), findsOneWidget);
      await openSheet(tester);
      expect(find.text('ada@example.org'), findsOneWidget);
      expect(find.text('ben@example.org'), findsOneWidget);
      expect(find.byKey(const ValueKey('instance-copy-owner-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('instance-delegate-email')), findsNothing);
      expect(find.byKey(const ValueKey('instance-withdraw-0')), findsNothing);
      expect(find.byKey(const ValueKey('instance-claim')), findsNothing);
      expect(find.byKey(const ValueKey('instance-you')), findsNothing);
    });

    testWidgets('a delegate is told so and still cannot delegate', (tester) async {
      await pumpTile(
        tester,
        const InstanceResponsibles(
          installationId: 'inst-1',
          you: InstanceRole.delegate,
          owners: [_owner],
          delegates: [_delegateForOthers],
        ),
      );
      await openSheet(tester);
      expect(find.byKey(const ValueKey('instance-you')), findsOneWidget);
      expect(find.byKey(const ValueKey('instance-delegate-email')), findsNothing);
      expect(find.byKey(const ValueKey('instance-withdraw-0')), findsNothing);
    });

    testWidgets('the owner delegates by e-mail and reads the outcome', (
      tester,
    ) async {
      final repo = await pumpTile(
        tester,
        const InstanceResponsibles(
          installationId: 'inst-1',
          you: InstanceRole.owner,
          owners: [_owner],
        ),
      );
      await openSheet(tester);
      repo.nextDelegation = DelegationOutcome.noAccount;
      await tester.enterText(
        find.byKey(const ValueKey('instance-delegate-email')),
        ' someone@example.org ',
      );
      await tester.tap(find.byKey(const ValueKey('instance-delegate-add')));
      await tester.pumpAndSettle();
      expect(repo.delegated, ['someone@example.org']);
      expect(
        find.text('No account uses this e-mail address.'),
        findsOneWidget,
      );
    });

    testWidgets('the owner withdraws a delegation only after confirming', (
      tester,
    ) async {
      final repo = await pumpTile(
        tester,
        const InstanceResponsibles(
          installationId: 'inst-1',
          you: InstanceRole.owner,
          owners: [_owner],
          delegates: [_delegateForOwner],
        ),
      );
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('instance-withdraw-0')));
      await tester.pumpAndSettle();
      expect(repo.withdrawn, isEmpty, reason: 'nothing before the confirmation');
      await tester.tap(find.byKey(const ValueKey('instance-withdraw-confirm')));
      await tester.pumpAndSettle();
      expect(repo.withdrawn, ['user-ben']);
      expect(find.text('Delegation withdrawn.'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation withdraws nothing', (tester) async {
      final repo = await pumpTile(
        tester,
        const InstanceResponsibles(
          installationId: 'inst-1',
          you: InstanceRole.owner,
          owners: [_owner],
          delegates: [_delegateForOwner],
        ),
      );
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('instance-withdraw-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.withdrawn, isEmpty);
    });

    testWidgets('a new instance offers its creator to take ownership', (
      tester,
    ) async {
      final repo = await pumpTile(
        tester,
        const InstanceResponsibles(installationId: 'inst-1', claimable: true),
      );
      await openSheet(tester);
      expect(find.byKey(const ValueKey('instance-owner-none')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('instance-claim')));
      await tester.pumpAndSettle();
      expect(repo.claims, 1);
      expect(find.text('You are now the instance owner.'), findsOneWidget);
    });

    testWidgets('an instance without an owner names nobody', (tester) async {
      await pumpTile(
        tester,
        const InstanceResponsibles(installationId: 'inst-1'),
      );
      expect(find.text('No instance owner is set yet.'), findsOneWidget);
      await openSheet(tester);
      expect(find.byKey(const ValueKey('instance-claim')), findsNothing);
      expect(find.byKey(const ValueKey('instance-delegate-email')), findsNothing);
    });
  });
}
