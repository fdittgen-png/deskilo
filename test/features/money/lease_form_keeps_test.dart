// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4498 (WS-07) -- the lease form carries and shows what the lease holds and a save keeps it: a lease with an area, two covered levels,
// a site, a responsible member and a contract document is amended (its premises line changes) and every one of the five is still on
// it afterwards, in what the form sends and in what the Demo then holds.
import 'dart:async';

import 'package:deskilo/core/demo/data/premises_lease_repository.dart';
import 'package:deskilo/features/money/domain/premises_lease.dart';
import 'package:deskilo/features/money/presentation/widgets/premises_lease_dialogs.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/premises_lease_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _lease = PremisesLease(
  id: 'lease-1',
  revision: 1,
  supplierId: 'sup-1',
  supplierName: 'Landlord',
  premises: '12 rue des Halles',
  coveredLevels: 'Ground, first',
  areaM2: 120.5,
  siteId: 'site-1',
  responsibleMemberId: 'member-1',
  contractDocumentId: 'doc-1',
  startsOn: DateTime(2026, 3),
  fixedUntil: DateTime(2029, 3),
  noticeMonths: 3,
  depositCents: 200000,
  status: LeaseStatus.draft,
);

void main() {
  testWidgets('a save that changes the premises keeps the area, the levels, the site, the member and the document', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakePremisesLeaseRepository()..leases.add(_lease);
    late BuildContext context;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premisesLeaseRepositoryProvider.overrideWithValue(repo),
          suppliersProvider.overrideWith((ref, ws) async => const [Supplier(id: 'sup-1', number: '1', name: 'Landlord')]),
          sitesProvider.overrideWith((ref) async => const [Site(id: 'site-1', workspaceId: 'ws', name: 'Main building')]),
          memberLabelsProvider.overrideWithValue(const {'member-1': 'Alex Martin'}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    unawaited(showLeaseDialog(context, 'ws', lease: _lease));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lease-area')), findsOneWidget);
    expect(find.text('120.5'), findsOneWidget, reason: 'the area is shown');
    expect(find.text('Ground, first'), findsOneWidget, reason: 'and the levels');
    expect(find.textContaining('Main building'), findsOneWidget, reason: 'the site is named');
    expect(find.textContaining('Alex Martin'), findsOneWidget, reason: 'and who is responsible');
    expect(find.byKey(const ValueKey('lease-document')), findsOneWidget, reason: 'and that a contract document is attached');

    await tester.enterText(find.byKey(const ValueKey('lease-premises')), '14 rue des Halles');
    await tester.ensureVisible(find.byKey(const ValueKey('lease-save')));
    await tester.tap(find.byKey(const ValueKey('lease-save')));
    await tester.pumpAndSettle();

    final kept = repo.leases.single;
    expect(kept.premises, '14 rue des Halles');
    expect((kept.areaM2, kept.coveredLevels), (120.5, 'Ground, first'));
    expect((kept.siteId, kept.responsibleMemberId, kept.contractDocumentId), ('site-1', 'member-1', 'doc-1'));
  });
}
