// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 -- the direct entries of a business without places: customers, quotes,
// invoices, a new invoice for a customer. One rule asks for each a feature that
// is on and a right the page asks; the overview of a business without places
// shows them and the overview of a business with places does not.
import 'package:deskilo/features/workspace/domain/business_entries.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/screens/workspace_overview_screen.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _selling = {
  WorkspaceFeature.invoicing,
  WorkspaceFeature.moneyTab,
  WorkspaceFeature.standaloneInvoicing,
  WorkspaceFeature.customerQuotes,
  WorkspaceFeature.billingCustomers,
};
const _issuer = {WorkspacePermission.issueInvoices};

void main() {
  group('businessEntriesFor', () {
    test('an issuer of a business that sells services has every entry', () {
      expect(businessEntriesFor(_selling, _issuer), [
        BusinessEntry.newInvoice,
        BusinessEntry.quotes,
        BusinessEntry.customers,
        BusinessEntry.invoices,
      ]);
    });

    test(
      'service fulfilment adds the engagements after the quotes, for who reads',
      () {
        final following = {..._selling, WorkspaceFeature.serviceFulfilment};

        expect(businessEntriesFor(following, _issuer), [
          BusinessEntry.newInvoice,
          BusinessEntry.quotes,
          BusinessEntry.engagements,
          BusinessEntry.customers,
          BusinessEntry.invoices,
        ]);
        expect(
          businessEntriesFor(following, {
            WorkspacePermission.manageBillingCustomers,
          }),
          [BusinessEntry.customers],
          reason: 'a customer manager who does not read the finances has no engagements',
        );
        expect(
          businessEntriesFor(_selling, _issuer),
          isNot(contains(BusinessEntry.engagements)),
        );
      },
    );

    test('a feature that is off offers no entry for it', () {
      final without = {..._selling}..remove(WorkspaceFeature.customerQuotes);

      expect(
        businessEntriesFor(without, _issuer),
        isNot(contains(BusinessEntry.quotes)),
      );
      expect(
        businessEntriesFor(
          {..._selling}..remove(WorkspaceFeature.invoicing),
          _issuer,
        ),
        isEmpty,
        reason: 'invoicing off: nothing is sold',
      );
    });

    test('a right the page asks is needed: a finance reader reads, only an '
        'issuer starts an invoice, and a person with none has nothing', () {
      expect(businessEntriesFor(_selling, {WorkspacePermission.viewFinances}), [
        BusinessEntry.quotes,
        BusinessEntry.customers,
        BusinessEntry.invoices,
      ]);
      expect(
        businessEntriesFor(_selling, {
          WorkspacePermission.manageBillingCustomers,
        }),
        [BusinessEntry.customers],
      );
      expect(businessEntriesFor(_selling, const {}), isEmpty);
    });
  });

  group('the overview', () {
    Future<GoRouter> open(
      WidgetTester tester, {
      required Set<WorkspaceFeature> features,
      Set<WorkspacePermission> rights = _issuer,
    }) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const WorkspaceOverviewScreen(),
          ),
          for (final path in [
            '/money/quotes',
            '/money/engagements',
            '/money/customers',
            '/invoices',
            '/me',
            '/invoicing/standalone/new',
          ])
            GoRoute(path: path, builder: (_, _) => Text('page:$path')),
        ],
      );
      await pumpApp(
        tester,
        null,
        router: router,
        overrides: [
          ...standardTestOverrides(),
          enabledFeaturesSyncProvider.overrideWithValue(features),
          myPermissionsProvider.overrideWithValue(rights),
          attentionProvider.overrideWith((ref) async => const []),
        ],
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets(
      'the engagements entry goes to its page when service fulfilment is on',
      (tester) async {
        await open(
          tester,
          features: {..._selling, WorkspaceFeature.serviceFulfilment},
        );

        await tester.tap(
          find.byKey(const ValueKey('business-entry-engagements')),
        );
        await tester.pumpAndSettle();
        expect(find.text('page:/money/engagements'), findsOneWidget);
      },
    );

    testWidgets('a business without places opens on its entries, each one '
        'going to its page', (tester) async {
      await open(tester, features: _selling);

      for (final key in [
        'business-entry-new-invoice',
        'business-entry-quotes',
        'business-entry-customers',
        'business-entry-invoices',
        'business-entry-me',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      await tester.tap(find.byKey(const ValueKey('business-entry-quotes')));
      await tester.pumpAndSettle();
      expect(find.text('page:/money/quotes'), findsOneWidget);
    });

    testWidgets('a business that books places shows none of them', (
      tester,
    ) async {
      await open(
        tester,
        features: {..._selling, WorkspaceFeature.placeBooking},
      );

      expect(find.byKey(const ValueKey('business-entries')), findsNothing);
    });

    testWidgets('a person with no right to sell sees no card', (tester) async {
      await open(tester, features: _selling, rights: const {});

      expect(find.byKey(const ValueKey('business-entries')), findsNothing);
    });
  });
}
