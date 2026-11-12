// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3782 — the layout of a form, measured: no field touches another (label,
// input and helper as the decorator draws them) and no helper or error is
// cut. The guard bites on two planted forms; then it runs over the forms of
// [_openers] at 390 and 1440 in the five languages.
//
// A form joins the measured list with one line in [_openers]: its name and
// a function that opens it from a context under the providers of [_scope]
// (add an override there if it needs one). The forms not yet measured are
// counted by the static net in test/lint/form_gap_test.dart, which only
// falls.
import 'dart:async';

import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/features/enabled_feature_keys.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/purchase_obligation.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/presentation/widgets/purchase_dialogs.dart';
import 'package:deskilo/features/money/presentation/widgets/purchase_offset_dialog.dart';
import 'package:deskilo/features/money/presentation/widgets/purchase_payment_dialogs.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'experience_guards.dart';

/// What a reimbursement or an offset settles: one open supplier bill.
const _claim = PurchaseObligation(
  id: 'ob-1',
  purchaseId: 'purchase-1',
  creditorKind: CreditorKind.supplier,
  creditorId: 's-1',
  amountCents: 12050,
  currency: 'EUR',
  appliedCents: 0,
  remainingCents: 12050,
);

/// The measured forms: a name, and how it opens.
final Map<String, void Function(BuildContext context)> _openers = {
  'purchase-bill': (c) => unawaited(showPurchaseBillDialog(c, 'ws')),
  'purchase-reimbursement': (c) =>
      unawaited(showReimbursementDialog(c, 'ws', _claim)),
  'purchase-offset': (c) => unawaited(showOffsetDialog(c, 'ws', _claim)),
};

Future<Widget> _scope(Locale locale) async {
  final suppliers = FakeSupplierRepository();
  final alpha = await suppliers.save('ws', const SupplierDraft(name: 'Alpha'));
  final orders = FakePurchaseOrderRepository(
    suppliers: () => suppliers.suppliers,
    services: () => const [],
    now: () => DateTime(2026, 5, 13),
  );
  final o = await orders.save(
    'ws',
    'seed',
    PurchaseOrderDraft(
      supplierId: alpha,
      lines: const [
        PurchaseOrderLineDraft(
          description: 'Capsules',
          quantity: 100,
          unitPriceCents: 25,
        ),
      ],
    ),
  );
  await orders.markSent('ws', o.id, o.revision, 'sent');
  return ProviderScope(
    overrides: [
      purchaseRepositoryProvider.overrideWithValue(FakePurchaseRepository()),
      supplierRepositoryProvider.overrideWithValue(suppliers),
      purchaseOrderRepositoryProvider.overrideWithValue(orders),
      // The order field shows, with its helper line.
      enabledFeatureKeysProvider.overrideWithValue({purchaseOrdersKey}),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox.expand()),
    ),
  );
}

Future<void> _plant(WidgetTester tester, Widget form) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, child: form)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('two fields without a gap fail', (tester) async {
    await _plant(
      tester,
      const Column(
        key: ValueKey('form'),
        children: [
          TextField(decoration: InputDecoration(labelText: 'One')),
          TextField(decoration: InputDecoration(labelText: 'Two')),
        ],
      ),
    );
    expect(
      formLayoutProblems(tester, form: find.byKey(const ValueKey('form'))),
      contains('fields without a gap'),
    );
  });

  testWidgets('a helper cut with an ellipsis fails; spaced fields with a '
      'helper that wraps pass', (tester) async {
    await _plant(
      tester,
      const Column(
        key: ValueKey('form'),
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Order',
              helperText:
                  'The order this bill charges: its amounts and its '
                  'lines are taken over when you pick it.',
              helperMaxLines: 1,
            ),
          ),
        ],
      ),
    );
    expect(
      formLayoutProblems(tester, form: find.byKey(const ValueKey('form'))),
      contains('helper cut'),
    );
    await _plant(
      tester,
      const Column(
        key: ValueKey('form'),
        spacing: 12,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Order',
              helperText:
                  'The order this bill charges: its amounts and its '
                  'lines are taken over when you pick it.',
              helperMaxLines: 4,
            ),
          ),
          TextField(decoration: InputDecoration(labelText: 'Two')),
        ],
      ),
    );
    expect(
      formLayoutProblems(tester, form: find.byKey(const ValueKey('form'))),
      isEmpty,
    );
  });

  for (final MapEntry(key: name, value: open) in _openers.entries) {
    for (final width in [390.0, 1440.0]) {
      for (final locale in AppLocalizations.supportedLocales) {
        testWidgets('$name at ${width.toInt()} in ${locale.languageCode}: '
            'no field touches another, no helper is cut', (tester) async {
          tester.view.physicalSize = Size(width, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(await _scope(locale));
          await tester.pumpAndSettle();
          open(tester.element(find.byType(Scaffold)));
          await tester.pumpAndSettle();
          final details = <String>[];
          expect(
            formLayoutProblems(
              tester,
              form: find.byType(Dialog),
              details: details,
            ),
            isEmpty,
            reason: details.join('\n'),
          );
        });
      }
    }
  }
}
