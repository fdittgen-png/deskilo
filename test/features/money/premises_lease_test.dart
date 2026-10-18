// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The premises lease: what the commands refuse before sending, the history of
// a rent that is superseded, notice, and the sheet from the list to the new
// amount. The server's own rules are proven in pgTAP 218.
import 'package:deskilo/core/demo/data/premises_lease_repository.dart';
import 'package:deskilo/core/demo/seed/demo_lease_seed.dart';
import 'package:deskilo/features/money/application/lease_commands.dart';
import 'package:deskilo/features/money/domain/premises_lease.dart';
import 'package:deskilo/features/money/domain/supplier.dart';
import 'package:deskilo/features/money/presentation/widgets/premises_lease_sheet.dart';
import 'package:deskilo/features/money/providers/premises_lease_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, List<Override> overrides) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: body)),
  ),
);

final _today = DateTime(2026, 10, 18);

LeaseDraft _draft({String request = 'r1'}) => LeaseDraft(
  supplierId: 'sup-1',
  premises: '12 rue des Halles',
  startsOn: DateTime(2026, 3),
  noticeMonths: 3,
  depositCents: 200000,
  requestId: request,
);

LeaseTermCommand _term(
  PremisesLease lease,
  int cents,
  DateTime from, {
  String request = 't1',
}) => LeaseTermCommand(
  leaseId: lease.id,
  revision: lease.revision,
  kind: LeaseTermKind.rent,
  amountCents: cents,
  effectiveFrom: from,
  requestId: request,
);

void main() {
  test('the permission the screen asks for is the catalogue\'s', () {
    expect(leaseManagePermission, WorkspacePermission.manageLease.wireName);
  });

  test('the commands send nothing for an entry that cannot be right', () async {
    final repo = FakePremisesLeaseRepository();
    final commands = LeaseCommands(repo);
    expect(
      await commands.save(
        'ws',
        LeaseDraft(
          supplierId: 'sup-1',
          premises: '  ',
          startsOn: DateTime(2026, 3),
          requestId: 'r0',
        ),
      ),
      isNull,
      reason: 'premises are named',
    );
    expect(
      await commands.save(
        'ws',
        LeaseDraft(
          supplierId: 'sup-1',
          premises: 'x',
          startsOn: DateTime(2026, 3),
          fixedUntil: DateTime(2026),
          requestId: 'r0',
        ),
      ),
      isNull,
      reason: 'a fixed term does not end before the lease starts',
    );
    expect(repo.leases, isEmpty);
    final lease = (await commands.save('ws', _draft()))!;
    expect(lease.status, LeaseStatus.draft);
    expect(
      await commands.addTerm('ws', lease, _term(lease, 0, DateTime(2026, 3))),
      isNull,
      reason: 'an amount above zero',
    );
    expect(
      await commands.addTerm(
        'ws',
        lease,
        _term(lease, 1000, DateTime(2026, 2)),
      ),
      isNull,
      reason: 'a term cannot start before the lease',
    );
    expect(
      await commands.giveNotice(
        'ws',
        lease,
        LeaseNoticeCommand(
          leaseId: lease.id,
          revision: lease.revision,
          givenOn: _today,
          effectiveEnd: _today,
          reason: 'x',
          requestId: 'n0',
        ),
      ),
      isNull,
      reason: 'only a running lease is ended',
    );
  });

  test('a new amount supersedes the one in force; history stays', () async {
    final repo = FakePremisesLeaseRepository();
    final commands = LeaseCommands(repo);
    var lease = (await commands.save('ws', _draft()))!;
    lease = (await commands.addTerm(
      'ws',
      lease,
      _term(lease, 100000, DateTime(2026, 3)),
    ))!;
    expect(lease.status, LeaseStatus.active);
    final same = await repo.addTerm(
      'ws',
      _term(lease, 100000, DateTime(2026, 3)),
    );
    expect(same.revision, lease.revision, reason: 'the same request replays');
    lease = (await commands.addTerm(
      'ws',
      lease,
      _term(lease, 105000, DateTime(2026, 9), request: 't2'),
    ))!;
    expect(
      [for (final t in lease.terms) (t.amountCents, t.effectiveTo?.day)],
      [(100000, 31), (105000, null)],
      reason: 'the first term closed the day before the second',
    );
    await expectLater(
      repo.addTerm('ws', _term(lease, 90000, DateTime(2026, 9), request: 't3')),
      throwsStateError,
      reason: 'a new term starts after the one in force',
    );
  });

  test('notice closes every term and records who and why', () async {
    final repo = seedDemoLease(_today);
    final commands = LeaseCommands(repo);
    final lease = (await repo.fetchLeases('ws')).single;
    final ended = (await commands.giveNotice(
      'ws',
      lease,
      LeaseNoticeCommand(
        leaseId: lease.id,
        revision: lease.revision,
        givenOn: _today,
        effectiveEnd: DateTime(2027, 6, 30),
        reason: 'moving',
        requestId: 'n1',
      ),
    ))!;
    expect(ended.status, LeaseStatus.noticeGiven);
    expect(ended.depositDueBackCents, 444000);
    expect(
      ended.terms.every((t) => t.effectiveTo == DateTime(2027, 6, 30)),
      isTrue,
    );
    expect(
      await commands.addTerm('ws', ended, _term(ended, 1, DateTime(2027, 7))),
      isNull,
    );
  });

  testWidgets(
    'the sheet lists the lease, its terms and the doors for who may',
    (tester) async {
      final repo = seedDemoLease(_today);
      Future<void> open({required bool manage}) async {
        await tester.pumpWidget(
          _app(
            PremisesLeaseView(
              workspaceId: 'ws',
              currencyCode: 'EUR',
              canManage: manage,
            ),
            [
              premisesLeaseRepositoryProvider.overrideWithValue(repo),
              suppliersProvider.overrideWith(
                (ref, ws) async => const [
                  Supplier(
                    id: 'demo-supplier-landlord',
                    number: '1',
                    name: 'SCI Les Remparts',
                  ),
                ],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
      }

      await open(manage: false);
      expect(find.text('4 rue de la Foire, 34120 Pézenas'), findsOneWidget);
      expect(find.byKey(const ValueKey('lease-add')), findsNothing);
      expect(
        find.byKey(const ValueKey('lease-term-add-demo-lease-premises')),
        findsNothing,
      );
      expect(find.textContaining('2,220.00'), findsWidgets);

      await open(manage: true);
      expect(find.byKey(const ValueKey('lease-add')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('lease-term-add-demo-lease-premises')),
      );
      await tester.pumpAndSettle();
      // Nothing entered: the dialog says so and sends nothing.
      await tester.tap(find.byKey(const ValueKey('term-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('term-invalid')), findsOneWidget);
      expect((await repo.fetchLeases('ws')).single.terms, hasLength(2));

      // Another charge starts on the day of the lease; the rent would have to
      // start after the one in force.
      await tester.tap(find.byKey(const ValueKey('term-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other charge').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('term-label')),
        'Parking',
      );
      await tester.enterText(find.byKey(const ValueKey('term-amount')), '80');
      await tester.tap(find.byKey(const ValueKey('term-from')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('term-save')));
      await tester.pumpAndSettle();
      final after = (await repo.fetchLeases('ws')).single;
      expect(after.terms, hasLength(3));
      expect(after.terms.last.amountCents, 8000);
      expect(after.terms.last.label, 'Parking');
    },
  );
}
