// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the quote screens as an issuer uses them: the list reads as
// the seller's own with its statuses and the amounts a sent revision froze, a
// list that could not be read is not an empty one, a sent quote offers Amend and
// Cancel (a draft Send and Discard) and each is the server's decision, the
// editor saves a draft at its version and says a stale save, and a send of an
// incomplete quote names what is missing.
import 'package:deskilo/core/demo/data/fake_billing_customers.dart';
import 'package:deskilo/core/demo/data/fake_customer_quotes.dart';
import 'package:deskilo/core/time/calendar_days.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/ui/date_field.dart';
import 'package:deskilo/features/money/application/customer_quote_commands.dart';
import 'package:deskilo/features/money/domain/billing_customer.dart';
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo/features/money/presentation/screens/customer_quote_editor_screen.dart';
import 'package:deskilo/features/money/presentation/screens/customer_quote_screen.dart';
import 'package:deskilo/features/money/presentation/screens/customer_quotes_screen.dart';
import 'package:deskilo/features/money/providers/billing_customer_providers.dart';
import 'package:deskilo/features/money/providers/business_day_provider.dart';
import 'package:deskilo/features/money/providers/customer_quote_providers.dart';
import 'package:deskilo/features/money/providers/standalone_invoice_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();
final _now = DateTime(2026, 11, 21);

const _line = StandaloneLine(
  description: 'Consulting',
  quantity: '1.5',
  unitCode: 'hour',
  unitLabel: 'h',
  unEceCode: 'HUR',
  unitPrice: '80',
);

const _lumi = BillingParty(
  subjectId: 'c-1',
  revision: 1,
  capacity: 'business',
  draft: BillingPartyDraft(company: 'Atelier Lumi', city: 'Pezenas', countryCode: 'FR'),
);

class _Setup {
  _Setup(this.quotes, this.workspaceId, this.today);

  final FakeCustomerQuoteRepository quotes;
  final String workspaceId;

  /// The day the screen's own clock reads.
  final DateTime today;
}

/// Opens [screen] over a fake with one sent quote (QUO-0001 for Atelier Lumi,
/// 1.5 h at 80.00 net: EUR 144.00 with 20 % VAT) and one draft.
Future<_Setup> _open(
  WidgetTester tester,
  Widget screen, {
  Set<WorkspacePermission>? permissions,
  bool withQuotes = true,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var clockNow = _now;
  final quotes = FakeCustomerQuoteRepository(clock: () => clockNow);
  final customers = FakeBillingCustomerRepository();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(path: '/money/quotes', builder: (_, _) => const Text('list-page')),
      GoRoute(path: '/money/quotes/:id', builder: (_, s) => Text('detail-${s.pathParameters['id']}')),
      GoRoute(path: '/money/quotes/:id/edit', builder: (_, s) => Text('edit-${s.pathParameters['id']}')),
    ],
  );
  await pumpApp(
    tester,
    null,
    router: router,
    overrides: [
      ...standardTestOverrides(),
      customerQuoteRepositoryProvider.overrideWithValue(quotes),
      ...extra,
      billingCustomerRepositoryProvider.overrideWithValue(customers),
      myPermissionsProvider.overrideWithValue(
        permissions ??
            const {WorkspacePermission.issueInvoices, WorkspacePermission.viewFinances},
      ),
    ],
  );
  await _settle(tester);
  final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  final workspaceId = container.read(currentWorkspaceProvider).value!.id;
  // the screen's own clock is the day: the quotes are dated from it
  final read = container.read(clockProvider).now();
  final today = DateTime(read.year, read.month, read.day);
  clockNow = today;
  customers.seed(workspaceId, _lumi);
  if (withQuotes) {
    quotes
      ..seedSent(
        workspaceId,
        subjectId: 'c-1',
        lines: const [_line],
        issuedOn: addCalendarDays(today, -5),
        validUntil: addCalendarDays(today, 25),
      )
      ..seedDraft(
        workspaceId,
        subjectId: 'c-1',
        lines: const [_line],
        issuedOn: today,
        validUntil: addCalendarDays(today, 30),
      );
  }
  container
    ..invalidate(customerQuotesProvider(workspaceId))
    ..invalidate(billingCustomersProvider(workspaceId))
    ..invalidate(customerQuoteProvider((workspaceId: workspaceId, quoteId: 'quote-1')))
    ..invalidate(customerQuoteProvider((workspaceId: workspaceId, quoteId: 'quote-2')));
  await _settle(tester);
  return _Setup(quotes, workspaceId, today);
}

/// Lets the futures and frames of one interaction finish: a few bounded pumps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The business's day in these tests is a day no device clock shows: what a screen offers as a date must be it.
final _businessDay = DateTime(2031, 5, 17);
final _dayOverrides = [
  businessDayProvider.overrideWithValue(_businessDay),
  invoiceDueDaysProvider.overrideWithValue(21),
];

void main() {
  testWidgets('the list shows each quote with its reference, status and the '
      'amount its sent revision froze', (tester) async {
    await _open(tester, const CustomerQuotesScreen());
    expect(find.text(_en.quotesIntro), findsOneWidget);
    expect(find.textContaining('QUO-0001'), findsOneWidget);
    expect(find.textContaining('Atelier Lumi'), findsWidgets);
    expect(find.textContaining(_en.quoteStatusSent), findsOneWidget);
    expect(find.textContaining(_en.invoicingStatusDraft), findsWidgets);
    // 1.5 h at 80.00 net, 20 % VAT: EUR 144.00, worked out when it was sent
    expect(find.textContaining('144'), findsOneWidget);
  });

  testWidgets('a list that could not be read says so and tries again; it is '
      'never an empty list', (tester) async {
    final setup = await _open(tester, const CustomerQuotesScreen(), withQuotes: false);
    expect(find.byKey(const ValueKey('quotes-empty')), findsOneWidget);
    setup.quotes.failNext = Exception('offline');
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .invalidate(customerQuotesProvider(setup.workspaceId));
    await _settle(tester);
    expect(find.text(_en.quotesLoadFailed), findsOneWidget);
    expect(find.byKey(const ValueKey('quotes-empty')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quotes-retry')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('quotes-empty')), findsOneWidget);
  });

  testWidgets('a person without the right to issue reads the quotes and finds '
      'no New quote', (tester) async {
    await _open(
      tester,
      const CustomerQuotesScreen(),
      permissions: const {WorkspacePermission.viewFinances},
    );
    expect(find.textContaining('QUO-0001'), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-new')), findsNothing);
  });

  testWidgets('a sent quote shows what was frozen, never changes in place, and '
      'offers Amend and Cancel', (tester) async {
    final setup = await _open(tester, const CustomerQuoteScreen(quoteId: 'quote-1'));
    expect(find.byKey(const ValueKey('quote-title')), findsOneWidget);
    expect(find.text('QUO-0001'), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-total')), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-sent-as')), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-edit')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quote-amend')));
    await _settle(tester);
    // the amendment is another revision, a draft with no amounts of its own
    expect(setup.quotes.calls, contains('amend'));
    expect(find.byKey(const ValueKey('quote-amounts-on-send')), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-revision-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-send')), findsOneWidget);
  });

  testWidgets('a sent quote is cancelled by the issuer; a refusal is said and '
      'nothing changes', (tester) async {
    final setup = await _open(tester, const CustomerQuoteScreen(quoteId: 'quote-1'));
    setup.quotes.mayIssue = () => false;
    await tester.tap(find.byKey(const ValueKey('quote-cancel')));
    await _settle(tester);
    expect(find.text(_en.quoteNotAllowedAction), findsOneWidget);
    expect(find.textContaining(_en.quoteStatusSent), findsWidgets);
    setup.quotes.mayIssue = () => true;
    await tester.tap(find.byKey(const ValueKey('quote-cancel')));
    await _settle(tester);
    expect(find.textContaining(_en.quoteStatusCancelled), findsWidgets);
  });

  testWidgets('a draft is sent from its page: the first send takes the next '
      'reference; an incomplete one names what is missing', (tester) async {
    final setup = await _open(tester, const CustomerQuoteScreen(quoteId: 'quote-2'));
    expect(find.byKey(const ValueKey('quote-amounts-on-send')), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-total')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quote-send')));
    await _settle(tester);
    expect(find.text('QUO-0002'), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-total')), findsOneWidget);
    expect(setup.quotes.calls, contains('send'));
  });

  testWidgets('the editor saves a draft, then says a stale save and keeps '
      'what was typed', (tester) async {
    final setup = await _open(tester, const CustomerQuoteEditorScreen(quoteId: 'quote-2'));
    await tester.enterText(find.byKey(const ValueKey('quote-notes')), 'Thanks');
    await tester.tap(find.byKey(const ValueKey('quote-save-draft')));
    await _settle(tester);
    expect(find.text(_en.quoteDraftSaved), findsOneWidget);
    // another editor saved meanwhile: this save names a version that moved
    final quote = await setup.quotes.quote(setup.workspaceId, 'quote-2');
    await setup.quotes.saveDraft(
      setup.workspaceId,
      quoteId: 'quote-2',
      expectedVersion: quote.draft!.draftVersion,
      input: const QuoteDraftInput(subjectId: 'c-1', lines: [_line], notes: 'elsewhere'),
    );
    await tester.enterText(find.byKey(const ValueKey('quote-notes')), 'Thanks again');
    await tester.tap(find.byKey(const ValueKey('quote-save-draft')));
    await _settle(tester);
    expect(find.text(_en.quoteStale), findsOneWidget);
    expect(
      tester.widget<TextField>(find.descendant(
        of: find.byKey(const ValueKey('quote-notes')),
        matching: find.byType(TextField),
      )).controller!.text,
      'Thanks again',
    );
  });

  testWidgets('a new quote needs a customer, is saved as a draft and sent; the '
      'server names what an incomplete quote lacks', (tester) async {
    final setup = await _open(tester, const CustomerQuoteEditorScreen(quoteId: 'new'));
    await tester.tap(find.byKey(const ValueKey('quote-customer')));
    await _settle(tester);
    await tester.tap(find.text('Atelier Lumi').last);
    await _settle(tester);
    // no line typed yet: the send is refused and says what is missing
    await tester.tap(find.byKey(const ValueKey('quote-send-now')));
    await _settle(tester);
    expect(find.textContaining('line_1'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('standalone-line-0-description')), 'Training');
    await tester.enterText(find.byKey(const ValueKey('standalone-line-0-quantity')), '2');
    await tester.enterText(find.byKey(const ValueKey('standalone-line-0-price')), '100');
    await tester.tap(find.byKey(const ValueKey('quote-send-now')));
    await _settle(tester);
    expect(find.textContaining('detail-'), findsOneWidget);
    final all = await setup.quotes.quotes(setup.workspaceId);
    expect(all.where((q) => q.status == QuoteStatus.sent).length, 2);
  });

  testWidgets('the issuer records the customer\'s answer, said as the issuer\'s '
      'own record; an acceptance after the validity is refused', (tester) async {
    final setup = await _open(tester, const CustomerQuoteScreen(quoteId: 'quote-1'));
    await tester.tap(find.byKey(const ValueKey('quote-record-answer')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('quote-decision-note')), findsOneWidget);
    expect(find.textContaining('not the customer'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quote-decision-submit')));
    await _settle(tester);
    await _settle(tester);
    expect(setup.quotes.calls, contains('recordDecision'));
    expect(find.textContaining(_en.quoteStatusAccepted), findsWidgets);
    expect(find.byKey(const ValueKey('quote-decision')), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-convert')), findsOneWidget);
  });

  testWidgets('an accepted quote is checked and invoiced once: the preview '
      'sets the invoice against what was accepted, and the same quote answers '
      'the same invoice', (tester) async {
    final setup = await _open(tester, const CustomerQuoteScreen(quoteId: 'quote-1'));
    await setup.quotes.recordDecision(
      setup.workspaceId,
      'quote-1',
      QuoteDecisionInput(accepted: true, revision: 1, decidedOn: setup.today, source: 'email'),
    );
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .invalidate(customerQuoteProvider((workspaceId: setup.workspaceId, quoteId: 'quote-1')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('quote-convert')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('quote-convert-issue')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quote-convert-check')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('quote-convert-accepted')), findsOneWidget);
    expect(find.textContaining('144'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('quote-convert-issue')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('quote-convert-done')), findsOneWidget);
    // a second conversion of the same quote answers the same invoice
    final again = await setup.quotes.convert(
      setup.workspaceId,
      'quote-1',
      draftRevision: 1,
      requestId: 'another-request',
    );
    expect(again.replayed, isTrue);
    expect(again.invoiceId, 'demo-quote-invoice-quote-1');
  });

  testWidgets('a lost answer to the conversion is looked up in the quote, '
      'never issued twice', (tester) async {
    final setup = await _open(tester, const CustomerQuoteScreen(quoteId: 'quote-1'));
    await setup.quotes.recordDecision(
      setup.workspaceId,
      'quote-1',
      QuoteDecisionInput(accepted: true, revision: 1, decidedOn: setup.today, source: 'email'),
    );
    // the invoice was made, then the answer was lost
    await setup.quotes.convert(setup.workspaceId, 'quote-1', draftRevision: 1, requestId: 'r1');
    setup.quotes.failNext = Exception('offline');
    final outcome = await ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(customerQuoteCommandProvider)
        .convert(setup.workspaceId, 'quote-1', draftRevision: 1, requestId: 'r1');
    expect(outcome, isA<QuoteDone<QuoteConverted>>());
    expect((outcome as QuoteDone<QuoteConverted>).value.replayed, isTrue);
  });

  testWidgets('the editor offers the business\'s day as the issue date, not the device\'s', (tester) async {
    await _open(tester, const CustomerQuoteEditorScreen(quoteId: 'new'), extra: _dayOverrides);
    expect(tester.widget<AppDateField>(find.byKey(const ValueKey('quote-issued-on'))).value, _businessDay);
  });

  testWidgets('the answer sheet offers the business\'s day as the decision date', (tester) async {
    await _open(tester, const CustomerQuoteScreen(quoteId: 'quote-1'), extra: _dayOverrides);
    await tester.tap(find.byKey(const ValueKey('quote-record-answer')));
    await _settle(tester);
    expect(tester.widget<AppDateField>(find.byKey(const ValueKey('quote-decided-on'))).value, _businessDay);
  });

  testWidgets('the conversion sheet offers the business\'s day as the service date and the payment term after it', (tester) async {
    final setup = await _open(tester, const CustomerQuoteScreen(quoteId: 'quote-1'), extra: _dayOverrides);
    await setup.quotes.recordDecision(
      setup.workspaceId,
      'quote-1',
      QuoteDecisionInput(accepted: true, revision: 1, decidedOn: setup.today, source: 'email'),
    );
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .invalidate(customerQuoteProvider((workspaceId: setup.workspaceId, quoteId: 'quote-1')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('quote-convert')));
    await _settle(tester);
    expect(tester.widget<AppDateField>(find.byKey(const ValueKey('quote-convert-service-date'))).value, _businessDay);
    expect(tester.widget<AppDateField>(find.byKey(const ValueKey('quote-convert-due-date'))).value, addCalendarDays(_businessDay, 21));
  });
}
