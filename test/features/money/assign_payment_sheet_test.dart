// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3671 (part 2) -- "Assign to invoices" as a person meets it: the prefill
// oldest first, a part below what is due with its prefilled note, the line
// that says the parts are too much, the honest empty and failed states, a
// refusal in the app's own words with a fresh read and what was typed kept,
// the result in plurals, a second tap that sends nothing -- and the rules of
// the experience in both postures (a sheet on a phone, a dialog at the desk).
import 'dart:async';

import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/invoicing/assign_payment_sheet.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_reads.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../ux/experience_guards.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

Finder _field(String id) => find.descendant(
  of: _key('assign-payment-amount-$id'),
  matching: find.byType(TextField),
);

String _text(WidgetTester tester, String id) =>
    tester.widget<TextField>(_field(id)).controller!.text;

bool _confirmEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.descendant(
            of: _key('assign-payment-confirm'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed !=
    null;

class _Repo extends FakeMoneyRepository {
  final applied =
      <({String payment, List<PaymentAllocation> parts, String note})>[];
  Exception? failWith;
  Exception? ledgerFails;
  Completer<void>? gate;
  bool pending = false;
  int ledgerReads = 0;

  /// The open invoices the reader turns the archive into.
  List<Receivable> open = [];

  /// The invoices whose payment awaits approval: the server lists them as
  /// unable to take a part.
  Set<String> held = {};
  Exception? capacityFails;

  @override
  Future<List<InvoiceCapacity>> paymentInvoiceCapacity({
    required String workspaceId,
    required String paymentLedgerId,
  }) async {
    final failure = capacityFails;
    if (failure != null) throw failure;
    return [
      for (final r in open)
        InvoiceCapacity(
          invoiceId: r.invoiceId,
          stillDueCents: held.contains(r.invoiceId) ? 0 : r.openMinor,
          canTake: !held.contains(r.invoiceId),
        ),
    ];
  }

  @override
  Future<PaymentApplied> applyPaymentToInvoices({
    required String workspaceId,
    required String paymentLedgerId,
    required List<PaymentAllocation> allocations,
    String note = '',
  }) async {
    applied.add((payment: paymentLedgerId, parts: allocations, note: note));
    final failure = failWith;
    if (failure != null) throw failure;
    await gate?.future;
    final entry = ledger.firstWhere((e) => e.id == paymentLedgerId);
    final left = remainingOf(entry);
    final sum = allocations.fold(0, (s, a) => s + a.amountCents);
    usePayment(paymentLedgerId, sum);
    open = [
      for (final r in open)
        if (allocations.where((a) => a.invoiceId == r.invoiceId).firstOrNull
            case final part?)
          if (part.amountCents < r.openMinor)
            _inv(r.invoiceId, r.openMinor - part.amountCents, r.dueOn!)
          else
            ...const <Receivable>[]
        else
          r,
    ];
    return PaymentApplied(invoices: allocations.length, leftCents: left - sum);
  }

  @override
  Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(
    String workspaceId,
  ) async => {
    if (pending)
      for (final a in applied.expand((c) => c.parts))
        a.invoiceId: InvoiceMatch(
          invoiceId: a.invoiceId,
          paidCents: a.amountCents,
          resolution: 'exact',
          status: 'pending',
          matchedAt: DateTime(2026, 4),
        ),
  };

  @override
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) async {
    ledgerReads++;
    final failure = ledgerFails;
    if (failure != null) throw failure;
    return super.fetchWorkspaceLedger(workspaceId);
  }
}

Receivable _inv(String id, int open, DateTime due) => Receivable(
  invoiceId: id,
  customerId: 'anna',
  customerName: 'Anna Alder',
  number: 'INV-$id',
  currency: 'EUR',
  totalMinor: open,
  openMinor: open,
  issuedOn: DateTime(2026, 3),
  dueOn: due,
  stage: ReceivableStage.open,
);

LedgerEntry _payment(String id, int cents) => LedgerEntry(
  id: id,
  memberId: 'anna',
  kind: LedgerKind.credit,
  category: LedgerCategory.payment,
  amountCents: cents,
  description: 'Transfer',
  period: '2026-03',
  createdAt: DateTime(2026, 3, 20),
  occurredOn: DateTime(2026, 3, 18),
);

void main() {
  late _Repo repo;
  final older = _inv('older', 5000, DateTime(2026, 4, 10));
  final newer = _inv('newer', 9000, DateTime(2026, 5, 10));

  setUp(() {
    repo = _Repo()
      ..open = [newer, older]
      ..ledger.add(_payment('p1', 12000));
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 900),
    double scale = 1.0,
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            money: repo,
            auth: FakeAuthRepository.signedIn(),
            workspace: FakeWorkspaceRepository.withWorkspace(),
          ),
          invoicingReceivablesProvider.overrideWith((ref) {
            ref.watch(invoicesProvider);
            return List.of(repo.open);
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(useMaterial3: true),
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open'),
              onPressed: () => showAssignPayment(
                context,
                paymentId: 'p1',
                customerId: 'anna',
                customerName: 'Anna Alder',
                currency: 'EUR',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(_key('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('an invoice whose payment awaits approval is shown with why, '
      'not offered; the prefill goes to the next one', (tester) async {
    repo.held = {'older'};
    await open(tester);
    expect(
      find.text('INV-older: a payment of it awaits approval; it takes no '
          'part now.'),
      findsOneWidget,
    );
    expect(_key('assign-payment-tick-older'), findsNothing);
    expect(_key('assign-payment-tick-newer'), findsOneWidget);
    await tester.tap(_key('assign-payment-confirm'));
    await tester.pumpAndSettle();
    expect(repo.applied.single.parts, [(invoiceId: 'newer', amountCents: 9000)]);
  });

  testWidgets('a failed read of what the invoices can take is said at once, '
      'with Try again', (tester) async {
    repo.capacityFails = Exception('offline');
    await open(tester);
    expect(_key('assign-payment-failed-capacity'), findsOneWidget);
    expect(_key('assign-payment-confirm'), findsNothing);
    repo.capacityFails = null;
    await tester.tap(_key('assign-payment-retry-capacity'));
    await tester.pumpAndSettle();
    expect(_key('assign-payment-confirm'), findsOneWidget);
  });

  testWidgets('the head says whose money it is; the amounts are prefilled '
      'oldest first, the last one a part, with the note ready', (tester) async {
    await open(tester);
    expect(find.text('Anna Alder'), findsOneWidget);
    expect(find.textContaining('Received'), findsOneWidget);
    expect(_text(tester, 'older'), '50');
    expect(_text(tester, 'newer'), '70', reason: '120.00 minus 50.00');
    expect(
      tester.getTopLeft(_key('assign-payment-row-older')).dy,
      lessThan(tester.getTopLeft(_key('assign-payment-row-newer')).dy),
    );
    expect(find.text('Nothing stays as credit'), findsOneWidget);
    expect(find.textContaining('50.00 still due'), findsOneWidget);
    expect(
      find.text('The payment covered only part of this invoice.'),
      findsOneWidget,
    );
    expect(_confirmEnabled(tester), isTrue);
  });

  testWidgets('a partly used payment reads received, already assigned, left '
      'and prefills from what is left', (tester) async {
    repo.usePayment('p1', 7000);
    await open(tester);
    expect(find.textContaining('already assigned'), findsOneWidget);
    expect(_text(tester, 'older'), '50');
    expect(_text(tester, 'newer'), isEmpty);
    expect(
      find.byKey(const ValueKey('assign-payment-note')),
      findsNothing,
      reason: 'the only part is the whole of its invoice: no note',
    );
  });

  testWidgets('an empty note switches the button off; money that stays is '
      'said', (tester) async {
    await open(tester);
    await tester.enterText(_field('newer'), '40');
    await tester.pump();
    expect(find.textContaining('30.00 stays as credit'), findsOneWidget);
    await tester.enterText(_key('assign-payment-note'), '');
    await tester.pump();
    expect(_confirmEnabled(tester), isFalse);
    expect(find.text('A note is required.'), findsOneWidget);
  });

  testWidgets('parts above what is left: the line is red, the button off', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(_field('older'), '90');
    await tester.pump();
    final line = tester.widget<Text>(_key('assign-payment-over'));
    expect(line.data, 'More than what is left of the payment');
    final context = tester.element(_key('assign-payment-over'));
    expect(line.style!.color, Theme.of(context).colorScheme.error);
    expect(_confirmEnabled(tester), isFalse);
    expect(find.text('More than what is due on this invoice'), findsOneWidget);
  });

  testWidgets('no open invoice: the payment stays as credit, no button', (
    tester,
  ) async {
    repo.open = [];
    await open(tester);
    expect(_key('assign-payment-no-open'), findsOneWidget);
    expect(
      find.text(
        'No open invoice for this customer: the payment stays as credit.',
      ),
      findsOneWidget,
    );
    expect(_key('assign-payment-confirm'), findsNothing);
  });

  testWidgets('a failed read names its source, has Try again and no button', (
    tester,
  ) async {
    repo.ledgerFails = Exception('offline');
    await open(tester);
    expect(find.text('The payment could not be read.'), findsOneWidget);
    expect(_key('assign-payment-confirm'), findsNothing);
    repo.ledgerFails = null;
    await tester.tap(_key('assign-payment-retry'));
    await tester.pumpAndSettle();
    expect(_key('assign-payment-confirm'), findsOneWidget);
  });

  testWidgets('a refusal is said in the app\'s words, the payment is read '
      'again and what was typed stays', (tester) async {
    repo.failWith = const PostgrestException(
      message: 'a part is more than what is due on its invoice',
    );
    await open(tester);
    await tester.enterText(_field('older'), '40');
    await tester.pump();
    final reads = repo.ledgerReads;
    await tester.tap(_key('assign-payment-confirm'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'A part is more than what is due on its invoice. Nothing was recorded.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('what is due on its invoice.'), findsOneWidget);
    expect(repo.ledgerReads, greaterThan(reads), reason: 'read again');
    expect(_text(tester, 'older'), '40', reason: 'what was typed is kept');
    expect(_key('assign-payment-confirm'), findsOneWidget);
  });

  testWidgets('success: the call carries the parts and the note; the result '
      'counts full and part, says what stays, never "undo"', (tester) async {
    await open(tester);
    await tester.enterText(_field('newer'), '40');
    await tester.pump();
    await tester.tap(_key('assign-payment-confirm'));
    await tester.pumpAndSettle();
    final call = repo.applied.single;
    expect(call.payment, 'p1');
    expect(call.parts.map((p) => (p.invoiceId, p.amountCents)), [
      ('older', 5000),
      ('newer', 4000),
    ]);
    expect(call.note, 'The payment covered only part of this invoice.');
    expect(find.text('1 invoice paid in full'), findsOneWidget);
    expect(find.text('1 invoice paid in part'), findsOneWidget);
    expect(find.textContaining('30.00 stays as credit'), findsOneWidget);
    expect(find.text('Waits for approval'), findsNothing);
    expect(
      find.textContaining(RegExp('undo', caseSensitive: false)),
      findsNothing,
    );
    await tester.tap(_key('assign-payment-close'));
    await tester.pumpAndSettle();
    expect(_key('assign-payment-result'), findsNothing);
  });

  testWidgets('a workspace that approves payments: the result says it waits', (
    tester,
  ) async {
    repo.pending = true;
    await open(tester);
    await tester.tap(_key('assign-payment-confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Waits for approval'), findsOneWidget);
    expect(find.text('1 invoice paid in full'), findsOneWidget);
  });

  testWidgets('busy: a second tap sends nothing', (tester) async {
    repo.gate = Completer<void>();
    await open(tester);
    await tester.tap(_key('assign-payment-confirm'));
    await tester.pump();
    await tester.tap(_key('assign-payment-confirm'), warnIfMissed: false);
    await tester.pump();
    expect(repo.applied, hasLength(1));
    expect(_confirmEnabled(tester), isFalse);
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(repo.applied, hasLength(1));
  });

  for (final dark in [false, true]) {
    for (final scale in guardScales) {
      for (final width in guardWidths) {
        testWidgets('${width < 900 ? 'the sheet' : 'the desk dialog'} keeps '
            'the rules at $width px, ×$scale, ${dark ? 'dark' : 'light'}', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          await open(
            tester,
            size: Size(width, 3000),
            scale: scale,
            mode: dark ? ThemeMode.dark : ThemeMode.light,
          );
          expect(
            find.byType(width < 900 ? BottomSheet : Dialog),
            findsOneWidget,
          );
          expect(find.byType(width < 900 ? Dialog : BottomSheet), findsNothing);
          expect(guardProblems(tester, width: width), isEmpty);
          // The two rows carry the invoice number in their names.
          expect(find.bySemanticsLabel('Pay invoice INV-older'), findsWidgets);
          expect(
            find.bySemanticsLabel(RegExp('Amount for invoice INV-older')),
            findsWidgets,
          );
          semantics.dispose();
        });
      }
    }
  }
}
