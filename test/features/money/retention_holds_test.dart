// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2571 -- the retention dialog of the accounting settings lists the space's
// legal holds; someone who manages billing places one (a kind of record, an
// issuer, a reason) and releases it with a reason. A reader without that
// right sees the holds and no action.
import 'package:deskilo/core/demo/data/book_profile_repository.dart';
import 'package:deskilo/features/money/domain/accounting_connection.dart';
import 'package:deskilo/features/money/presentation/widgets/retention_clocks_tile.dart';
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Atelier',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

Future<FakeRetentionHoldRepository> _open(
  WidgetTester tester, {
  required Set<String> permissions,
  FakeRetentionHoldRepository? repository,
}) async {
  final repo =
      repository ??
      FakeRetentionHoldRepository(now: () => DateTime(2026, 10, 26, 9));
  await pumpApp(
    tester,
    const Scaffold(
      body: RetentionClocksTile(country: 'FR', workspaceId: 'ws-1'),
    ),
    size: const Size(900, 1600),
    overrides: [
      currentWorkspaceProvider.overrideWith((ref) async => _workspace),
      accountingSystemsScopeProvider.overrideWithValue(
        AccountingSystemsScope(
          countryCode: 'FR',
          issuers: const {'site-south': 'South'},
          permissions: permissions,
          memberNames: const {},
        ),
      ),
      retentionHoldRepositoryProvider.overrideWithValue(repo),
    ],
  );
  await tester.pumpAndSettle();
  await _tap(tester, find.byKey(const ValueKey('retention-clocks')));
  return repo;
}

/// A tap and what it opens or closes, settled.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'someone who manages billing places a hold on one issuer\'s books and releases it',
    (tester) async {
      final repo = await _open(tester, permissions: {'manageBilling'});
      expect(find.textContaining('No hold is in place'), findsOneWidget);

      await _tap(tester, find.byKey(const ValueKey('retention-hold-place')));
      // No reason: nothing is sent, the field says why.
      await _tap(tester, find.byKey(const ValueKey('retention-hold-save')));
      expect(repo.holds, isEmpty);
      expect(
        find.text('Name the reason, in at most 500 characters.'),
        findsOneWidget,
      );

      await _tap(tester, find.byKey(const ValueKey('retention-hold-class')));
      await _tap(tester, find.text('Books').last);
      await _tap(tester, find.byKey(const ValueKey('retention-hold-issuer')));
      await _tap(tester, find.text('South').last);
      await tester.enterText(
        find.byKey(const ValueKey('retention-hold-reason')),
        'tax audit 2026',
      );
      await _tap(tester, find.byKey(const ValueKey('retention-hold-save')));

      final hold = repo.holds.single;
      expect(
        (hold.docClass, hold.issuerSiteId, hold.reason),
        ('books', 'site-south', 'tax audit 2026'),
      );
      expect(find.text('tax audit 2026'), findsOneWidget);
      expect(find.text('Books · South · since Oct 26, 2026'), findsOneWidget);

      await _tap(
        tester,
        find.byKey(ValueKey('retention-hold-release-${hold.id}')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('retention-hold-release-reason')),
        'audit closed',
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('retention-hold-release-save')),
      );
      expect(repo.holds.single.active, isFalse);
      expect(repo.holds.single.releaseReason, 'audit closed');
      expect(
        find.textContaining('No hold is in place'),
        findsOneWidget,
        reason: 'a released hold no longer keeps anything',
      );
    },
  );

  testWidgets('a reader without billing rights sees the holds and no action', (
    tester,
  ) async {
    final repo = FakeRetentionHoldRepository(now: () => DateTime(2026, 10, 2));
    await repo.placeHold(
      workspaceId: 'ws-1',
      reason: 'dispute with a supplier',
    );
    await _open(tester, permissions: {'viewFinances'}, repository: repo);
    expect(find.text('dispute with a supplier'), findsOneWidget);
    expect(
      find.text('Every kind of record · Every issuer · since Oct 2, 2026'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('retention-hold-place')), findsNothing);
    expect(
      find.byKey(ValueKey('retention-hold-release-${repo.holds.single.id}')),
      findsNothing,
    );
  });
}
