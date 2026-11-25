// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 — a quote as a document. The sent offer is printed through the report
// system as its own `quote` kind: it carries the quote's reference and the word
// Quote, the customer, how long it is valid, the lines and what the issuer
// froze for them (the net, the VAT per rate, the total) — and no invoice number:
// nothing was invoiced. A draft has no document. Quick view, save or share like
// every report.
import 'package:deskilo/core/demo/data/fake_billing_customers.dart';
import 'package:deskilo/core/demo/data/fake_customer_quotes.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:deskilo/core/time/calendar_days.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/domain/billing_customer.dart';
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/domain/quote_report.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo/features/money/presentation/screens/customer_quote_screen.dart';
import 'package:deskilo/features/money/providers/billing_customer_providers.dart';
import 'package:deskilo/features/money/providers/customer_quote_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

const _consulting = StandaloneLine(
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
  draft: BillingPartyDraft(
    company: 'Atelier Lumi',
    street: '3 rue des Arts',
    postalCode: '34120',
    city: 'Pezenas',
    countryCode: 'FR',
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The quote screen of a sent quote (QUO-0001, 1.5 h at 80.00 net, 20 %: EUR
/// 144.00) or of a draft, with the share seam recording what it was given.
Future<({List<({List<int> bytes, String name})> shared, String quoteId})> _open(
  WidgetTester tester, {
  bool sent = true,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final shared = <({List<int> bytes, String name})>[];
  var clockNow = DateTime(2026, 11, 21);
  final quotes = FakeCustomerQuoteRepository(clock: () => clockNow);
  final customers = FakeBillingCustomerRepository();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const CustomerQuoteScreen(quoteId: 'quote-1'),
      ),
    ],
  );
  await pumpApp(
    tester,
    null,
    router: router,
    overrides: [
      ...standardTestOverrides(
        fileSharer:
            ({
              required bytes,
              required fileName,
              required mimeType,
              text,
            }) async {
              shared.add((bytes: bytes, name: fileName));
              return FileShareOutcome.sent;
            },
      ),
      customerQuoteRepositoryProvider.overrideWithValue(quotes),
      billingCustomerRepositoryProvider.overrideWithValue(customers),
      myPermissionsProvider.overrideWithValue(const {
        WorkspacePermission.issueInvoices,
        WorkspacePermission.viewFinances,
      }),
    ],
  );
  await _settle(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  );
  final workspaceId = container.read(currentWorkspaceProvider).value!.id;
  final read = container.read(clockProvider).now();
  final today = DateTime(read.year, read.month, read.day);
  clockNow = today;
  customers.seed(workspaceId, _lumi);
  if (sent) {
    quotes.seedSent(
      workspaceId,
      subjectId: 'c-1',
      lines: const [_consulting],
      issuedOn: addCalendarDays(today, -5),
      validUntil: addCalendarDays(today, 25),
    );
  } else {
    quotes.seedDraft(
      workspaceId,
      subjectId: 'c-1',
      lines: const [_consulting],
      issuedOn: today,
      validUntil: addCalendarDays(today, 30),
    );
  }
  container
    ..invalidate(billingCustomersProvider(workspaceId))
    ..invalidate(
      customerQuoteProvider((workspaceId: workspaceId, quoteId: 'quote-1')),
    );
  await _settle(tester);
  return (shared: shared, quoteId: 'quote-1');
}

String _previewText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('report-quick-preview')),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join('\n');

void main() {
  testWidgets('a sent quote opens as a document: its reference, the word '
      'Quote, the customer, the validity and the amounts it froze — and no '
      'invoice number', (tester) async {
    await _open(tester);

    await tester.tap(find.byKey(const ValueKey('quote-print')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quote-print-quick')));
    await tester.pumpAndSettle();

    final text = _previewText(tester);
    expect(text, contains('QUO-0001'));
    expect(text, contains(_en.reportDocQuote));
    expect(text, contains('Atelier Lumi'));
    expect(text, contains('Pezenas'));
    expect(text, contains('Consulting'));
    expect(text, contains('120.00'), reason: 'the net the issuer froze');
    expect(text, contains('144.00'), reason: 'the total the issuer froze');
    expect(text, matches(RegExp(r'20\s?%')));
    expect(
      text.toLowerCase(),
      isNot(contains('invoice')),
      reason: 'nothing was invoiced: no invoice word or number',
    );
  });

  testWidgets('the document is shared as a PDF named for the quote', (
    tester,
  ) async {
    final opened = await _open(tester);

    await tester.tap(find.byKey(const ValueKey('quote-print')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quote-print-share')));
    await tester.pumpAndSettle();

    expect(opened.shared, hasLength(1));
    expect(opened.shared.single.name, 'quote-QUO-0001.pdf');
    expect(String.fromCharCodes(opened.shared.single.bytes.take(5)), '%PDF-');
  });

  testWidgets('a draft has no document to share', (tester) async {
    await _open(tester, sent: false);

    expect(find.byKey(const ValueKey('quote-print')), findsNothing);
  });

  group('quoteReportData', () {
    QuoteFormats formats() => (
      money: (minor) => '€${(minor / 100).toStringAsFixed(2)}',
      date: (d) => '${d.day}/${d.month}/${d.year}',
      quantity: (text) => text,
      price: (text) => text,
      percent: (p) => '${p.toStringAsFixed(0)} %',
    );

    CustomerQuote quoteOf() {
      Map<String, Object?> line(
        String label,
        String net,
        String tax,
        num pct,
      ) => {
        'label': label,
        'supply': 'general',
        'vat_percent': pct,
        'commercial': {
          'quantity': '1',
          'unit': {'code': 'unit', 'label': 'x'},
          'unit_price': {'amount': net, 'basis': 'net', 'base_quantity': '1'},
          'amounts': {
            'net_minor': net,
            'tax_minor': tax,
            'gross_minor': '${int.parse(net) + int.parse(tax)}',
          },
        },
      };
      return CustomerQuote.fromJson({
        'quote_id': 'q',
        'subject_id': 's',
        'reference': 'QUO-0007',
        'status': 'sent',
        'expired': false,
        'revisions': [
          {
            'revision': 2,
            'draft_version': 1,
            'status': 'sent',
            'issued_on': '2026-11-01',
            'valid_until': '2026-12-01',
            'purchase_order': 'PO-9',
            'buyer_reference': 'BR-1',
            'notes': 'Thank you',
            'lines': [
              line('A', '10000', '2000', 20),
              line('B', '5000', '500', 10),
              line('C', '2000', '400', 20),
            ],
            'totals': const {'total_cents': 19900, 'currency': 'EUR'},
          },
        ],
      });
    }

    test('the reference, the validity, the notes and the customer\'s own '
        'references are the quote\'s; the VAT is the lines\' per rate', () {
      final quote = quoteOf();
      final data = quoteReportData(
        quote,
        quote.current!,
        customer: (name: 'Atelier Lumi', address: 'Pezenas'),
        format: formats(),
        issuedBy: 'Seller',
      );

      expect(data['number'], 'QUO-0007');
      expect(data['valid_until'], '1/12/2026');
      expect(data['issued'], '1/11/2026');
      expect(data['note'], 'Thank you');
      expect(data['purchase_order'], 'PO-9');
      expect(data['buyer_reference'], 'BR-1');
      expect(data['client_name'], 'Atelier Lumi');
      expect(data['net_total'], '€170.00');
      expect(data['vat_total'], '€29.00');
      expect(
        data['total'],
        '€199.00',
        reason: 'the frozen total, not a new sum',
      );
      expect(data['has_vat'], isTrue);
      expect(data['vat'], [
        {'rate': '20 %', 'net': '€120.00', 'amount': '€24.00'},
        {'rate': '10 %', 'net': '€50.00', 'amount': '€5.00'},
      ]);
      expect((data['lines']! as List).length, 3);
    });
  });
}
