// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the Demo runs the billing access without a server, through its own
// composition: the account already reads Hanna Weiss's invoices as a customer,
// the owner invites Nordlicht GmbH and the account accepts the code, Me then
// shows two debtors of ONE seller and currency apart (never as what the account
// owes as a member), and a revocation ends the reading and erases nothing.
import 'package:deskilo/core/demo/demo_finances.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/money/domain/billing_access.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter_test/flutter_test.dart';

/// #4168 — the account also holds a grant of Kessler Conseil (Lindner
/// Beratung); this journey is the head business's.
List<BilledSubject> _head(FinanceOverview o) => [
  for (final g in o.billedGroups)
    if (g.workspaceId == demoFirstSpaceId) g,
];

void main() {
  late DemoFixture fixture;

  setUp(() => fixture = DemoFixture.build());

  test('the account already reads the invoices of Hanna Weiss, apart from '
      'what it owes as a member', () {
    final overview = demoFinanceOverview(fixture);
    final groups = _head(overview);
    expect(groups.map((g) => g.subjectId), ['demo-customer-weiss']);
    expect(
      groups.single.invoices.map((i) => i.number),
      contains('AR-2026-0412'),
    );
    expect(overview.invoices.every((i) => !i.billingOnly), isTrue);
    expect(
      overview.invoices.any(
        (i) => i.financialSubjectId == 'demo-customer-weiss',
      ),
      isFalse,
    );
  });

  test('an invited customer is read after the code is accepted, as another '
      'debtor of the same seller and currency', () async {
    final access = fixture.stores.home.billingAccess;
    final invitation = await access.invite(
      demoFirstSpaceId,
      'demo-customer-nordlicht',
      'req-1',
    );
    expect(
      _head(demoFinanceOverview(fixture)),
      hasLength(1),
      reason: 'an invitation alone grants nothing',
    );
    await access.accept(invitation.code);
    final groups = _head(demoFinanceOverview(fixture));
    expect(groups.map((g) => g.subjectId), [
      'demo-customer-nordlicht',
      'demo-customer-weiss',
    ]);
    expect(groups.map((g) => g.workspaceId).toSet(), {demoFirstSpaceId});
    expect(groups.map((g) => g.openByCurrency.keys.single).toSet(), {'EUR'});
    expect(groups.first.openByCurrency, {'EUR': 180000});
    expect(groups.last.openByCurrency, {
      'EUR': 24000,
    }, reason: 'its paid invoice is not open');
  });

  test('a revocation ends the reading, keeps the grant as history and the '
      'customer stays a customer', () async {
    final access = fixture.stores.home.billingAccess;
    final grant = (await access.grantsOf(
      demoFirstSpaceId,
      'demo-customer-weiss',
    )).single;
    expect(grant.stateAt(fixture.seededAt), BillingGrantState.active);
    await access.revoke(grant.id, reason: 'moved');
    expect(_head(demoFinanceOverview(fixture)), isEmpty);
    final after = (await access.grantsOf(
      demoFirstSpaceId,
      'demo-customer-weiss',
    )).single;
    expect(after.stateAt(fixture.seededAt), BillingGrantState.revoked);
    expect(
      fixture.stores.home.billingCustomers
          .of(demoFirstSpaceId)
          .any((c) => c.subjectId == 'demo-customer-weiss'),
      isTrue,
    );
  });

  test('another space starts with no grants of its own to invite', () async {
    final access = fixture.stores.home.billingAccess;
    expect(
      () => access.invite(demoSecondSpaceId, 'demo-customer-weiss', 'req-1'),
      throwsA(
        isA<BillingAccessRefusal>().having(
          (e) => e.kind,
          'kind',
          BillingAccessRefusalKind.notACustomer,
        ),
      ),
    );
  });
}
