// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-c -- the invoicing home's guard table. Each state -- populated,
// empty, one source failed, two currencies -- by customer and by invoice, at
// 320, 390 and 1280 px, at text scale 1.0 and 1.3, light and dark, must pass
// the experience guards (test/ux/experience_guards.dart): no overflow, one
// filled button at phone width, every control 48 dp and named. The two-
// currency state never prints a sum of its currencies. With SHEET=1 it
// writes build/sheets/invoicing/<state>--<view>--<width>--<theme>.png.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_home.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import 'experience_guards.dart';

/// The business's day the table is drawn on.
final _today = DateTime(2026, 11, 10);

Receivable _r(
  String no,
  String name, {
  required String due,
  int amount = 10000,
  String currency = 'CHF',
  int sent = 0,
  int? dueLevel,
  bool declared = false,
  bool hold = false,
  ReceivableStage stage = ReceivableStage.open,
  String? paid,
}) => Receivable(
  invoiceId: no,
  customerId: name,
  customerName: name,
  number: '2026-$no',
  currency: currency,
  totalMinor: amount,
  openMinor: stage == ReceivableStage.paid ? 0 : amount,
  issuedOn: DateTime.parse(due).subtract(const Duration(days: 14)),
  dueOn: DateTime.parse(due),
  stage: stage,
  remindersSent: sent,
  reminderDueLevel: dueLevel,
  paymentDeclared: declared,
  declaredOn: declared ? DateTime(2026, 11, 9) : null,
  onHold: hold,
  paidOn: paid == null ? null : DateTime.parse(paid),
);

/// The prototype's sample space, in Swiss francs.
final _sample = [
  _r('0063', 'SASU KaloA', due: '2026-09-21', sent: 1, dueLevel: 2),
  _r('0064', 'Ma Petite Entreprise', due: '2026-09-23', sent: 1, dueLevel: 2),
  _r('0071', 'Atelier Nord', due: '2026-10-12', amount: 42000, declared: true),
  _r('0077', 'L. Moreau', due: '2026-10-20', amount: 5000, dueLevel: 1),
  _r('0079', 'Studio Sud', due: '2026-10-22', amount: 21000, dueLevel: 1),
  _r('0080', 'Kontor GmbH', due: '2026-11-01', amount: 98100, hold: true),
  _r('0086', 'SASU KaloA', due: '2026-10-21'),
  _r('0090', 'Praxis am See', due: '2026-11-20', amount: 64000),
  _r('0091', 'Linea Design', due: '2026-11-25', amount: 48000),
  _r(
    '0058',
    'Praxis am See',
    due: '2026-10-15',
    amount: 64000,
    stage: ReceivableStage.paid,
    paid: '2026-11-03',
  ),
];

InvoicingHomeData _data(
  List<Receivable> rs, {
  Set<InvoicingSource> failed = const {},
}) => InvoicingHomeData(
  receivables: rs,
  today: _today,
  month: 'November',
  toInvoiceMonth: 'October',
  currency: 'CHF',
  mode: ReminderMode.byHand,
  toInvoice: rs.isEmpty
      ? const []
      : const [
          (customerId: 'nord', currency: 'CHF', amountMinor: 48000),
          (customerId: 'mor', currency: 'CHF', amountMinor: 5000),
        ],
  received: [
    if (rs.isNotEmpty)
      (currency: 'CHF', minor: 386000, on: DateTime(2026, 11, 3)),
    if (rs.any((r) => r.currency == 'EUR'))
      (currency: 'EUR', minor: 12000, on: DateTime(2026, 11, 4)),
  ],
  failed: failed,
);

final Map<String, InvoicingHomeData> _states = {
  'populated': _data(_sample),
  'empty': _data(const []),
  'one source failed': _data(_sample, failed: {InvoicingSource.payments}),
  'a status source failed': _data(
    _sample,
    failed: {InvoicingSource.matches, InvoicingSource.reminders},
  ),
  'two currencies': _data([
    ..._sample,
    _r(
      '0101',
      'Kontor GmbH',
      due: '2026-10-30',
      amount: 98100,
      currency: 'EUR',
    ),
  ]),
};

const _noActions = InvoicingHomeActions(
  onOpenInvoice: _ignore,
  onOpenCustomer: _ignore,
  onCustomerAction: _ignore2,
  onTodo: _ignore,
  onRetry: _ignore,
  onNewInvoice: _ignore0,
);
void _ignore0() {}
void _ignore(Object? _) {}
void _ignore2(Object? _, Object? _) {}

Future<void> _pump(
  WidgetTester tester,
  InvoicingHomeData data, {
  required double width,
  required bool dark,
  required double scale,
  required InvoicingView view,
}) async {
  await pumpApp(
    tester,
    RepaintBoundary(
      child: Theme(
        data: dark ? DeskiloTheme.dark() : DeskiloTheme.light(),
        child: Scaffold(
          appBar: AppBar(title: const Text('Invoices')),
          body: InvoicingHome(data: data, actions: _noActions),
        ),
      ),
    ),
    // Tall enough that no row is cut by the viewport (see the Me guards).
    size: Size(width, width < 600 ? 7000 : 2400),
    textScale: scale,
  );
  await tester.pumpAndSettle();
  if (view == InvoicingView.invoices &&
      data.receivables.isNotEmpty &&
      !data.failed.any(InvoicingSource.statuses.contains)) {
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('invoicing-view')),
        matching: find.text('Invoices'),
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final MapEntry(key: state, value: data) in _states.entries) {
    for (final view in InvoicingView.values) {
      testWidgets('$state · ${view.name}', (tester) async {
        await loadSheetFonts();
        final semantics = tester.ensureSemantics();
        final problems = <String, Set<String>>{};
        for (final dark in [false, true]) {
          for (final scale in guardScales) {
            for (final width in guardWidths) {
              await _pump(
                tester,
                data,
                width: width,
                dark: dark,
                scale: scale,
                view: view,
              );
              final tag = '$width px, ×$scale, ${dark ? 'dark' : 'light'}';
              for (final p in guardProblems(tester, width: width)) {
                problems.putIfAbsent(p, () => {}).add(tag);
              }
              if (state == 'two currencies') {
                // CHF and EUR are never added: no line says their sum.
                expect(find.textContaining('1,962'), findsNothing);
              }
              if (scale == 1.0 && width != 320) {
                await writeSheet(
                  tester,
                  sheet: 'invoicing',
                  name:
                      '${state.replaceAll(' ', '-')}--${view.name}--${width.toInt()}--${dark ? 'dark' : 'light'}',
                );
              }
            }
          }
        }
        semantics.dispose();
        expect(problems, isEmpty);
      });
    }
  }
}
