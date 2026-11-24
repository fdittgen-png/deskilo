// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the three screens as a person uses them, on a phone (390) and at
// a desk (1440): the seller invites a billing customer and is shown the code
// ONCE, revokes a grant, and is told in words when it may not; the account
// previews and accepts a code and is told in words when it cannot be used; Me
// shows what a business invoiced the account as a customer APART from what it
// owes as a member, each debtor of one seller on its own card.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/demo/data/fake_billing_access.dart';
import 'package:deskilo/core/demo/data/fake_billing_customers.dart';
import 'package:deskilo/features/money/domain/billing_customer.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/presentation/screens/billing_customers_screen.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/features/money/providers/billing_customer_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

const _lumi = BillingParty(
  subjectId: 'c-1',
  revision: 1,
  capacity: 'business',
  draft: BillingPartyDraft(company: 'Atelier Lumi', city: 'Pezenas'),
);

const _sizes = <String, Size>{
  'phone 390': Size(390, 844),
  'desk 1440': Size(1440, 900),
};

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

FakeBillingAccessRepository _access(String ws) => FakeBillingAccessRepository(
  clock: () => DateTime.utc(2026, 11, 24, 9),
  customerOf: (w, id) => w == ws && id == _lumi.subjectId ? _lumi : null,
  workspaceNameOf: (_) => 'Atelier du Marché',
);

Future<(FakeBillingAccessRepository, String)> _openSeller(
  WidgetTester tester,
  Size size,
) async {
  _size(tester, size);
  final customers = FakeBillingCustomerRepository();
  late FakeBillingAccessRepository access;
  await pumpApp(
    tester,
    const BillingCustomersScreen(),
    overrides: [
      ...standardTestOverrides(),
      billingCustomerRepositoryProvider.overrideWithValue(customers),
      billingAccessRepositoryProvider.overrideWith((ref) => access),
    ],
  );
  await _settle(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(BillingCustomersScreen)),
  );
  final ws = container.read(currentWorkspaceProvider).value!.id;
  access = _access(ws);
  container.invalidate(billingAccessRepositoryProvider);
  customers.seed(ws, _lumi);
  container.invalidate(billingCustomersProvider(ws));
  await _settle(tester);
  return (access, ws);
}

Future<void> _openAccessDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('billing-customer-access-c-1')));
  await _settle(tester);
}

void main() {
  for (final MapEntry(key: label, value: size) in _sizes.entries) {
    group('seller, $label', () {
      testWidgets('the code is shown once; a grant is listed, then revoked and '
          'kept as history', (tester) async {
        final (access, ws) = await _openSeller(tester, size);
        await _openAccessDialog(tester);
        expect(find.text(_en.billingAccessNone), findsOneWidget);
        expect(find.byKey(const ValueKey('billing-access-code')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('billing-access-invite')));
        await _settle(tester);
        final code = tester
            .widget<SelectableText>(
              find.byKey(const ValueKey('billing-access-code')),
            )
            .data!;
        expect(code, isNotEmpty);
        expect(find.textContaining(_en.billingAccessCodeTitle), findsWidgets);
        final grant = (await access.grantsOf(ws, 'c-1')).single;
        expect(
          find.byKey(ValueKey('billing-access-grant-${grant.id}')),
          findsOneWidget,
        );

        // Closed and opened again: the code is gone, the grant remains.
        await tester.tap(find.byKey(const ValueKey('billing-access-close')));
        await _settle(tester);
        await _openAccessDialog(tester);
        expect(find.byKey(const ValueKey('billing-access-code')), findsNothing);
        expect(find.text(code), findsNothing);
        expect(
          find.byKey(ValueKey('billing-access-grant-${grant.id}')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(ValueKey('billing-access-revoke-${grant.id}')),
        );
        await _settle(tester);
        expect(
          find.byKey(ValueKey('billing-access-revoke-${grant.id}')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey('billing-access-grant-${grant.id}')),
          findsOneWidget,
        );
        expect((await access.grantsOf(ws, 'c-1')).single.revokedAt, isNotNull);
      });

      testWidgets('without the right the refusal is worded and nothing is '
          'created', (tester) async {
        final (access, ws) = await _openSeller(tester, size);
        await _openAccessDialog(tester);
        access.mayManage = () => false;
        await tester.tap(find.byKey(const ValueKey('billing-access-invite')));
        await _settle(tester);
        expect(find.text(_en.billingAccessNotAllowed), findsOneWidget);
        expect(find.byKey(const ValueKey('billing-access-code')), findsNothing);
        access.mayManage = () => true;
        expect(await access.grantsOf(ws, 'c-1'), isEmpty);
      });

      testWidgets('a lost answer claims nothing; the retry is the same '
          'invitation, never a second', (tester) async {
        final (access, ws) = await _openSeller(tester, size);
        await _openAccessDialog(tester);
        access.failNext = StateError('offline');
        await tester.tap(find.byKey(const ValueKey('billing-access-invite')));
        await _settle(tester);
        expect(find.text(_en.billingAccessFailed), findsOneWidget);
        expect(find.byKey(const ValueKey('billing-access-code')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('billing-access-invite')));
        await _settle(tester);
        expect(
          find.byKey(const ValueKey('billing-access-code')),
          findsOneWidget,
        );
        expect(find.text(_en.billingAccessFailed), findsNothing);
        expect(await access.grantsOf(ws, 'c-1'), hasLength(1));
      });

      testWidgets('a list that could not be read is not "no invitations"; '
          'try again reads it', (tester) async {
        final (access, _) = await _openSeller(tester, size);
        access.failNext = StateError('offline');
        await _openAccessDialog(tester);
        expect(find.text(_en.billingAccessNone), findsNothing);
        expect(
          find.byKey(const ValueKey('billing-access-retry')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('billing-access-retry')));
        await _settle(tester);
        expect(find.text(_en.billingAccessNone), findsOneWidget);
      });
    });

    group('account, $label', () {
      Future<FakeBillingAccessRepository> open(WidgetTester tester) async {
        _size(tester, size);
        final access = _access('ws-1');
        final overview = FakeAccountActivityRepository(
          derive: () => const FinanceOverview(),
        );
        await pumpApp(
          tester,
          const MyFinancesScreen(),
          overrides: [
            ...standardTestOverrides(accountActivity: overview),
            billingAccessRepositoryProvider.overrideWithValue(access),
          ],
        );
        await _settle(tester);
        return access;
      }

      testWidgets('a code is previewed, then accepted', (tester) async {
        final access = await open(tester);
        final code = (await access.invite('ws-1', 'c-1', 'r-1')).code;
        await tester.tap(find.byKey(const ValueKey('billing-access-enter')));
        await _settle(tester);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('billing-access-code-field')),
            matching: find.byType(EditableText),
          ),
          code.toLowerCase(),
        );
        await tester.tap(find.byKey(const ValueKey('billing-access-check')));
        await _settle(tester);
        expect(
          find.text(
            _en.billingAccessPreviewLine('Atelier du Marché', 'Atelier Lumi'),
          ),
          findsOneWidget,
        );
        expect(
          access.heldSubjects,
          isEmpty,
          reason: 'a preview grants nothing',
        );
        await tester.tap(find.byKey(const ValueKey('billing-access-accept')));
        await _settle(tester);
        expect(
          find.byKey(const ValueKey('billing-access-done')),
          findsOneWidget,
        );
        expect(access.heldSubjects, {'c-1'});
      });

      testWidgets('an unusable code is told in words, one answer, and '
          'nothing is held', (tester) async {
        final access = await open(tester);
        await tester.tap(find.byKey(const ValueKey('billing-access-enter')));
        await _settle(tester);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('billing-access-code-field')),
            matching: find.byType(EditableText),
          ),
          'WRONG',
        );
        await tester.tap(find.byKey(const ValueKey('billing-access-check')));
        await _settle(tester);
        expect(find.text(_en.billingAccessCodeUnusable), findsOneWidget);
        expect(
          find.byKey(const ValueKey('billing-access-accept')),
          findsNothing,
        );
        expect(access.heldSubjects, isEmpty);
      });

      testWidgets('a lost answer is recoverable: the same code is checked '
          'again', (tester) async {
        final access = await open(tester);
        final code = (await access.invite('ws-1', 'c-1', 'r-1')).code;
        await tester.tap(find.byKey(const ValueKey('billing-access-enter')));
        await _settle(tester);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('billing-access-code-field')),
            matching: find.byType(EditableText),
          ),
          code,
        );
        access.failNext = StateError('offline');
        await tester.tap(find.byKey(const ValueKey('billing-access-check')));
        await _settle(tester);
        expect(find.text(_en.billingAccessFailed), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('billing-access-check')));
        await _settle(tester);
        expect(
          find.byKey(const ValueKey('billing-access-preview')),
          findsOneWidget,
        );
        expect(find.text(_en.billingAccessFailed), findsNothing);
      });
    });

    group('Me, $label', () {
      testWidgets('billed documents are shown apart, one card per debtor, and '
          'are not what I owe as a member', (tester) async {
        _size(tester, size);
        FinanceInvoice row(
          String id,
          String subject,
          int total, {
          bool billed = true,
        }) => FinanceInvoice(
          id: id,
          workspaceId: 'ws-1',
          workspaceName: 'Atelier du Marché',
          number: 'N-$id',
          issuedAt: DateTime.utc(2026, 11),
          dueOn: DateTime.utc(2026, 12, 20),
          totalCents: total,
          paidCents: 0,
          currency: 'EUR',
          state: FinanceState.open,
          stillDueCents: total,
          timezone: 'Europe/Paris',
          financialSubjectId: subject,
          billingOnly: billed,
        );
        final overview = FinanceOverview(
          invoices: [row('m', 'me', 5000, billed: false)],
          billed: [
            row('a', 'subject-acme-111111', 12000),
            row('p', 'subject-self-222222', 3000),
          ],
        );
        await pumpApp(
          tester,
          const MyFinancesScreen(),
          overrides: standardTestOverrides(
            accountActivity: FakeAccountActivityRepository()
              ..financeOverview = overview,
          ),
        );
        await _settle(tester);
        expect(find.byKey(const ValueKey('billed-section')), findsOneWidget);
        expect(find.byKey(const ValueKey('billed-invoice-a')), findsOneWidget);
        expect(find.byKey(const ValueKey('billed-invoice-p')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('billed-open-ws-1-subject-acme-111111')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('billed-open-ws-1-subject-self-222222')),
          findsOneWidget,
        );
        // What I owe as a member is the member document alone.
        expect(
          find.byKey(const ValueKey('finances-to-pay-EUR')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('finances-to-pay-EUR')))
              .data,
          contains('50'),
        );
      });
    });
  }
}
