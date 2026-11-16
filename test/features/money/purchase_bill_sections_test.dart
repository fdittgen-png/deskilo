// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4065 — the supplier-bill form groups its fields under five headings, in
// the order a bill is read: supplier and document, amount and tax, payment,
// accounting, description and item. The fields that may stay empty say so.
// A refused save names each field in error at the top, and each name takes
// the focus to its field. Keys, checks and what is saved are unchanged.
import 'dart:async';

import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/ui/form_kit.dart';
import 'package:deskilo/features/money/presentation/widgets/purchase_dialogs.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        purchaseRepositoryProvider.overrideWithValue(FakePurchaseRepository()),
        suppliersProvider.overrideWith(
          (ref, ws) async => const [
            Supplier(id: 's-1', number: '401', name: 'Papeterie Martin'),
          ],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open'),
              onPressed: () => unawaited(showPurchaseBillDialog(context, 'ws')),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

bool _focusedInside(WidgetTester tester, Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final element = tester.element(target);
  var inside = identical(focused, element);
  focused.visitAncestorElements((a) => !(inside = identical(a, element)));
  return inside;
}

void main() {
  for (final size in const [Size(1440, 900), Size(390, 844)]) {
    testWidgets('at ${size.width.toInt()} px: five headings in order, the '
        'optional fields say so', (tester) async {
      await _open(tester, size);
      final titles = [
        for (final s in tester.widgetList<FormSection>(
          find.byType(FormSection),
        ))
          s.title,
      ];
      expect(titles, [
        _en.purchaseBillSectionSupplier,
        _en.purchaseBillSectionAmount,
        _en.invoicePageMorePayment,
        _en.purchaseBillSectionAccounting,
        _en.purchaseBillSectionDescription,
      ]);
      final tops = [
        for (final e in find.byType(FormSection).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      ];
      expect(tops, [...tops]..sort(), reason: 'drawn in that order');
      Finder within(String section, String key) => find.descendant(
        of: find.ancestor(
          of: find.text(section),
          matching: find.byType(FormSection),
        ),
        matching: find.byKey(ValueKey(key)),
      );
      expect(
        within(_en.purchaseBillSectionSupplier, 'purchase-supplier'),
        findsOneWidget,
      );
      expect(
        within(_en.purchaseBillSectionSupplier, 'purchase-reference'),
        findsOneWidget,
      );
      expect(
        within(_en.purchaseBillSectionSupplier, 'purchase-invoice-date'),
        findsOneWidget,
      );
      expect(
        within(_en.purchaseBillSectionAmount, 'purchase-gross'),
        findsOneWidget,
      );
      expect(
        within(_en.purchaseBillSectionAmount, 'purchase-tax'),
        findsOneWidget,
      );
      expect(
        within(_en.invoicePageMorePayment, 'purchase-due-date'),
        findsOneWidget,
      );
      expect(
        within(_en.purchaseBillSectionAccounting, 'purchase-purpose'),
        findsOneWidget,
      );
      expect(
        within(_en.purchaseBillSectionDescription, 'purchase-description'),
        findsOneWidget,
      );
      for (final label in [
        _en.purchasesSupplier,
        _en.purchasesReference,
        _en.purchasesInvoiceDate,
        _en.purchasesTaxField,
        _en.purchasesDueDate,
        _en.purchasesDescription,
      ]) {
        expect(
          find.text(_en.purchaseBillOptional(label)),
          findsOneWidget,
          reason: label,
        );
      }
      expect(
        find.text(_en.purchaseBillOptional(_en.purchasesGross)),
        findsNothing,
      );
      expect(find.text(_en.purchasesGross), findsOneWidget, reason: 'required');
    });

    testWidgets('at ${size.width.toInt()} px: an amount that is not a number '
        'is named at the top, and its name focuses the field', (tester) async {
      await _open(tester, size);
      await tester.enterText(
        find.byKey(const ValueKey('purchase-gross')),
        'abc',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('purchase-save')));
      await tester.tap(find.byKey(const ValueKey('purchase-save')));
      await tester.pumpAndSettle();
      final link = find.byKey(const ValueKey('purchase-problem-gross'));
      expect(link, findsOneWidget);
      expect(
        find.descendant(of: link, matching: find.text(_en.purchasesGross)),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('purchase-problem-tax')), findsNothing);
      // At the top: above the first heading.
      expect(
        tester.getTopLeft(link).dy,
        lessThan(
          tester.getTopLeft(find.text(_en.purchaseBillSectionSupplier)).dy,
        ),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(
        _focusedInside(tester, find.byKey(const ValueKey('purchase-gross'))),
        isFalse,
      );
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(
        _focusedInside(tester, find.byKey(const ValueKey('purchase-gross'))),
        isTrue,
      );
    });
  }
}
