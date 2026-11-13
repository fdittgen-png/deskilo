// SPDX-License-Identifier: AGPL-3.0-or-later
// All human demo accounts own documents in two currencies. Personal history
// reads the same records, follows the signed-in user and preserves membership
// status; a kiosk never gains a personal account balance.
import 'package:deskilo/core/demo/demo_finance_projection.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_personal_repositories.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_personal_currency_seed.dart';
import 'package:deskilo/core/demo/seed/demo_twin_seed.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_owed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'personal state survives persona scopes and retains the entitled twin',
    () async {
      final f = DemoFixture.build();
      var scope = ProviderContainer(overrides: demoOverrides(f));
      var me = scope.read(meRepositoryProvider);
      final twin = (await me.myWorkspaceRefs()).refs
          .singleWhere((r) => r.workspaceId == demoTwinSpaceId)
          .networkId;
      await me.setAccountFavorite(twin, on: true);
      scope.dispose();
      f.becomePersona(DemoPersona.member);
      scope = ProviderContainer(overrides: demoOverrides(f));
      me = scope.read(meRepositoryProvider);
      expect(
        (await me.myWorkspaceRefs()).refs.every((r) => !r.isFavorite),
        isTrue,
      );
      scope.dispose();
      f.becomePersona(DemoPersona.owner);
      scope = ProviderContainer(overrides: demoOverrides(f));
      addTearDown(scope.dispose);
      me = scope.read(meRepositoryProvider);
      expect(
        (await me.myWorkspaceRefs()).refs
            .singleWhere((r) => r.networkId == twin)
            .isFavorite,
        isTrue,
      );
    },
  );

  test(
    'currency completion is repeatable and preserves pending/paused roles',
    () {
      final f = DemoFixture.build();
      final before = [
        for (final s in f.personalSpaces)
          (s.money.invoices.length, s.workspaces.otherMembers.length),
      ];
      completeDemoPersonalCurrencies(
        f.personalSpaces,
        now: f.seededAt,
        companionSpaces: [
          (workspaces: f.zurich.workspaces, money: f.zurich.money),
          (workspaces: f.milan.workspaces, money: f.milan.money),
        ],
      );
      expect([
        for (final s in f.personalSpaces)
          (s.money.invoices.length, s.workspaces.otherMembers.length),
      ], before);
      for (final original in f.workspaces.otherMembers.where(
        (m) =>
            m.status == MemberStatus.paused || m.status == MemberStatus.pending,
      )) {
        final companions = [f.zurich.workspaces, f.milan.workspaces]
            .expand((s) => s.otherMembers)
            .where((m) => m.userId == original.userId)
            .toList();
        expect(companions, isNotEmpty);
        for (final member in companions) {
          expect(member.status, original.status);
          expect(member.subscriptionPct, 0);
          expect(
            member.isOwner || member.isAdmin || member.actsAsOwner,
            isFalse,
          );
        }
      }
    },
  );

  test('every human account has at least two own outstanding currencies', () {
    final f = DemoFixture.build(now: DateTime.utc(2027, 2, 9, 10));
    final users = {
      for (final s in f.personalSpaces)
        for (final m in [s.workspaces.myMember, ...s.workspaces.otherMembers])
          if (!m.isKiosk && m.userId.isNotEmpty) m.userId,
    };
    for (final user in users) {
      f.auth.signInAs(user);
      final result = demoFinanceForUser(f.personalSpaces, f.auth.currentUserId);
      expect(result.owedByCurrency, demoOwedFromTheSpaces(f), reason: user);
      expect(
        result.owedByCurrency.length,
        greaterThanOrEqualTo(2),
        reason: user,
      );
      for (final i in result.invoices) {
        final s = f.personalSpaces.singleWhere(
          (s) => s.workspaces.myMember.workspaceId == i.workspaceId,
        );
        final source = s.money.invoices.singleWhere((row) => row.id == i.id);
        final member = [
          s.workspaces.myMember,
          ...s.workspaces.otherMembers,
        ].singleWhere((m) => m.id == source.memberId);
        expect(member.userId, user, reason: '${i.workspaceId}/${i.id}');
        expect(member.isKiosk, isFalse);
      }
    }
    f.becomePersona(DemoPersona.kiosk);
    expect(demoFinanceForUser(f.personalSpaces, f.auth.currentUserId).invoices, isEmpty);
  });

  test('personal references and history follow the current account', () async {
    final f = DemoFixture.build();
    final me = demoPersonalMe(
      spaces: () => f.personalSpaces,
      currentUser: () => f.auth.currentUserId,
    );
    final activity = demoPersonalActivity(
      spaces: () => f.personalSpaces,
      currentUser: () => f.auth.currentUserId,
    );
    for (final persona in [DemoPersona.owner, DemoPersona.member]) {
      f.becomePersona(persona);
      final expected = {
        for (final s in f.personalSpaces)
          for (final m in [s.workspaces.myMember, ...s.workspaces.otherMembers])
            if (m.userId == persona.userId && !m.isKiosk)
              m.workspaceId: m.status.name,
      };
      final refs = await me.myWorkspaceRefs();
      expect({
        for (final r in refs.refs) r.workspaceId: r.status?.name,
      }, expected);
      final invoices = await everyActivityPage(
        (before) => activity.list(AccountActivityKind.invoices, before: before),
      );
      expect(invoices, isNotEmpty);
      expect(
        invoices.map((i) => (i.workspaceId, i.id)).toSet().length,
        invoices.length,
      );
      final ownIds = {
        for (final s in f.personalSpaces)
          for (final m in [s.workspaces.myMember, ...s.workspaces.otherMembers])
            if (m.userId == persona.userId && !m.isKiosk)
              for (final i in s.money.invoices)
                if (i.memberId == m.id) (i.workspaceId, i.id),
      };
      expect(invoices.map((i) => (i.workspaceId, i.id)).toSet(), ownIds);
      expect(await activity.list(AccountActivityKind.payments), isNotEmpty);
    }
    final paused = f.personalSpaces
        .expand((s) => [s.workspaces.myMember, ...s.workspaces.otherMembers])
        .firstWhere((m) => m.status == MemberStatus.paused);
    f.auth.signInAs(paused.userId);
    final refs = await me.myWorkspaceRefs();
    expect(
      refs.refs
          .firstWhere((r) => r.workspaceId == paused.workspaceId)
          .status
          ?.name,
      'paused',
    );
    f.becomePersona(DemoPersona.kiosk);
    expect(await activity.list(AccountActivityKind.payments), isEmpty);
    expect((await me.myWorkspaceRefs()).refs, isEmpty);
  });
}
