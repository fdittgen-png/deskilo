// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3031 — a purchase in another currency than the space's is booked at the
// exchange rate recorded with it. What a typed rate may be; how an entry is
// converted (each line once, half up, the rounding cents to the largest line
// of the short side, every line keeping its original); the server's
// converted entry and its missingRate blocker as the app reads them; the
// posted FEC writing Montantdevise/Idevise from the engine's originals; a
// book whose only blockers are missing rates naming the documents; the
// payload a bill in another currency sends; the demonstration's rate rules;
// and on screen, the bill captured in francs with its rate and the rate
// entered on the document.
import 'dart:io';

import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/features/enabled_feature_keys.dart';
import 'package:deskilo/core/i18n/currencies.dart';
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/application/purchase_commands.dart';
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/domain/book_profile_repository.dart';
import 'package:deskilo/features/money/domain/fec_postings.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/posting_fx.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/credit_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

FxRate _rate(String rate, {String base = 'CHF', String quote = 'EUR'}) =>
    FxRate(
      base: base,
      quote: quote,
      rate: ExactDecimal.parse(rate),
      source: 'bank',
      date: DateTime(2026, 5, 12),
      version: '1',
    );

PostingLine _l(
  BookRole role,
  String code,
  int debit,
  int credit, [
  String c = 'CHF',
]) => PostingLine(
  role: role,
  accountCode: code,
  debit: AccountingAmount(c, debit),
  credit: AccountingAmount(c, credit),
);

Posting _bill(List<PostingLine> lines) => Posting(
  journal: PostingJournal.purchases,
  date: DateTime(2026, 5, 12),
  kind: PostingKind.supplierBill,
  documentId: 'b-chf',
  documentNumber: 'CH-1',
  lines: lines,
);

PurchaseDetail _francDraft({PurchaseState state = PurchaseState.pending}) =>
    PurchaseDetail(
      summary: PurchaseSummary(
        id: 'b-chf',
        kind: PurchaseKind.bill,
        state: state,
        category: 'Licence',
        reference: 'CH-1',
        currency: 'CHF',
        grossCents: 48000,
      ),
      revision: 1,
      lines: const [
        PurchaseLine(lineNo: 1, description: 'Licence', grossCents: 48000),
      ],
      sources: const [],
    );

ExchangeRateEntry _entry(String rate, [String source = 'bank']) =>
    ExchangeRateEntry(
      rate: ExactDecimal.parse(rate),
      rateDate: DateTime(2026, 5, 12),
      source: source,
    );

class _Books implements BookProfileRepository {
  _Books(this.set);
  final PostingSet set;

  @override
  Future<PostingSet> fetchPostings(
    String workspaceId,
    String issuerSiteId,
    DateTime from,
    DateTime to,
  ) async => set;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('unexpected ${invocation.memberName}');
}

final _localBook = BookProfile(
  id: 'p',
  workspaceId: 'ws',
  issuerSiteId: 'site',
  authority: BookAuthority.localBook,
  externalSystem: '',
  functionalCurrency: 'EUR',
  fiscalYearStartMonth: 1,
  fiscalYearStartDay: 1,
  basis: AccountingBasis.accrual,
  effectiveFrom: DateTime(2020),
  revision: 1,
);

Widget _scope(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: PurchasesView(
          workspaceId: 'ws',
          canCapture: true,
          canDecide: true,
        ),
      ),
    ),
  ),
);

/// One frame, then long enough for a route, a menu or a picker to finish
/// opening or closing.
Future<void> _step(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  test('a typed rate: digits with a point or a comma, positive, at most '
      'ten decimals', () {
    expect(parseExchangeRate('1,0657').rate, ExactDecimal.parse('1.0657'));
    expect(parseExchangeRate(' 0.93 ').rate, ExactDecimal.parse('0.93'));
    expect(parseExchangeRate('abc').error, ExchangeRateEntryError.notANumber);
    expect(parseExchangeRate('-1').error, ExchangeRateEntryError.notANumber);
    expect(
      parseExchangeRate('0.000').error,
      ExchangeRateEntryError.notPositive,
    );
    expect(
      parseExchangeRate('1.12345678901').error,
      ExchangeRateEntryError.tooPrecise,
    );
    expect(parseExchangeRate('1.1234567890').error, isNull);
  });

  test('an entry at its rate: each line once, half up, balanced on the '
      'largest line of the short side, every line with its original', () {
    // 100.01 + 33.34 + 33.33 = 166.68 CHF at 1.0657:
    // 106.58 + 35.53 + 35.52 = 177.63 on the debit, 177.63 on the credit.
    final p = postingAtRate(
      _bill([
        _l(BookRole.expenses, '606', 10001, 0),
        _l(BookRole.expenses, '606', 3334, 0),
        _l(BookRole.expenses, '606', 3333, 0),
        _l(BookRole.suppliers, '401', 0, 16668),
      ]),
      _rate('1.0657'),
    );
    expect([for (final l in p.lines) l.debit.minor], [10658, 3553, 3552, 0]);
    expect(p.lines.last.credit.minor, 17763);
    expect(p.balanced, isTrue);
    expect(p.lines.every((l) => l.debit.currency == 'EUR'), isTrue);
    expect(
      [for (final l in p.lines) l.original?.minor],
      [10001, 3334, 3333, 16668],
    );

    // 0.01 × 3 at 0.5: each 0.005 rounds up to 0.01, the whole 0.015 to
    // 0.02: the credit (short) takes the cent.
    final gap = postingAtRate(
      _bill([
        _l(BookRole.expenses, '606', 1, 0),
        _l(BookRole.expenses, '606', 1, 0),
        _l(BookRole.expenses, '606', 1, 0),
        _l(BookRole.suppliers, '401', 0, 3),
      ]),
      _rate('0.5'),
    );
    expect(gap.balanced, isTrue);
    expect(gap.lines.last.credit.minor, 3);

    // A currency without minor units: 5 000 JPY at 0.0062 is 31.00 EUR.
    final yen = postingAtRate(
      _bill([
        _l(BookRole.expenses, '606', 5000, 0, 'JPY'),
        _l(BookRole.suppliers, '401', 0, 5000, 'JPY'),
      ]),
      _rate('0.0062', base: 'JPY'),
    );
    expect(yen.lines.first.debit.minor, 3100);
  });

  test('the server\'s converted entry and its missing-rate blocker as the '
      'app reads them', () {
    final set = PostingSet.fromJson({
      'postings': [
        {
          'journal': 'purchases',
          'kind': 'supplier_bill',
          'date': '2026-05-12',
          'document_id': 'b-chf',
          'document_number': 'CH-1',
          'currency': 'EUR',
          'original_currency': 'CHF',
          'exchange_rate': {
            'rate': '1.0657',
            'rate_date': '2026-05-12',
            'source': 'bank',
          },
          'lines': [
            {
              'role': 'expenses',
              'account_code': '606',
              'debit_cents': 25577,
              'credit_cents': 0,
              'original_cents': 24000,
            },
            {
              'role': 'suppliers',
              'account_code': '401',
              'debit_cents': 0,
              'credit_cents': 25577,
              'original_cents': 24000,
            },
          ],
        },
      ],
      'blockers': [
        {'block': 'missingRate', 'subject': 'CH-2 (USD)'},
      ],
    });
    final line = set.postings.single.lines.first;
    expect(line.debit, AccountingAmount('EUR', 25577));
    expect(line.original, AccountingAmount('CHF', 24000));
    expect(set.blockers.single.block, PostingBlock.missingRate);
    expect(set.blockers.single.subject, 'CH-2 (USD)');

    // The posted FEC writes the engine's originals, no rate map needed.
    final fec = buildFecFromPostings(
      set.postings,
      accountNames: const {'606': 'Achats', '401': 'Fournisseurs'},
      parties: const {
        'b-chf': PostingParty(kind: 'supplier', number: '23', name: 'Léman SA'),
      },
      functionalCurrency: 'EUR',
    );
    expect(fec.blockers, isEmpty);
    final rows = fec.file.trim().split('\r\n').skip(1).toList();
    expect(rows, hasLength(2));
    for (final r in rows) {
      expect(r.split('\t').sublist(16), ['240,00', 'CHF']);
    }
  });

  test('a book whose only blockers are missing rates names the documents; '
      'with a role to map, the roles come first', () async {
    Future<GenericJournal> read(List<PostingBlocker> blockers) =>
        GenericJournalExport(_Books(PostingSet(const [], blockers)))
            .read('ws', [_localBook], 2026);
    final rates = await read(const [
      PostingBlocker(PostingBlock.missingRate, 'CH-1 (CHF)'),
      PostingBlocker(PostingBlock.missingRate, 'US-4 (USD)'),
    ]);
    expect((rates as JournalNeedsRates).documents, [
      'CH-1 (CHF)',
      'US-4 (USD)',
    ]);
    final roles = await read(const [
      PostingBlocker(PostingBlock.missingRate, 'CH-1 (CHF)'),
      PostingBlocker(PostingBlock.unmappedRole, 'expenses'),
    ]);
    expect((roles as JournalBlocked).roles, ['expenses']);
  });

  test('the minor digits the server converts with are the app\'s', () {
    final latest =
        (Directory('supabase/migrations')
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('.sql'))
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path)))
            .map((f) => f.readAsStringSync())
            .lastWhere(
              (s) => s.contains(
                'create or replace function public.currency_minor_digits(',
              ),
            );
    final body = latest.substring(
      latest.indexOf(
        'create or replace function public.currency_minor_digits(',
      ),
    );
    Set<String> listed(String digits) {
      final m = RegExp(r"any \(array\[([^\]]*)\]\) then " + digits)
          .firstMatch(body)!;
      return {
        for (final c in RegExp(r"'([A-Z]{3})'").allMatches(m.group(1)!))
          c.group(1)!,
      };
    }

    expect(listed('0'), Currencies.zeroDecimal);
    expect(listed('3'), Currencies.threeDecimal);
  });

  test('a bill in another currency sends its currency and its rate', () {
    final payload = PurchaseBillDraft(
      grossCents: 48000,
      currency: 'CHF',
      exchangeRate: _entry('1.0657', 'tax_authority'),
    ).toPayload();
    expect(payload['currency'], 'CHF');
    expect(payload['exchange_rate'], {
      'rate': '1.0657',
      'rate_date': '2026-05-12',
      'source': 'tax_authority',
    });
    final own = const PurchaseBillDraft(grossCents: 100).toPayload();
    expect(own.containsKey('currency'), isFalse);
    expect(own.containsKey('exchange_rate'), isFalse);
  });

  test('a rate is corrected until approval and fixed after; a document in '
      'the space\'s currency gets none', () async {
    final repo = FakePurchaseRepository()..add(_francDraft());
    final commands = PurchaseCommands(repo);
    final s = (await repo.fetchDetail('ws', 'b-chf')).summary;
    final first = await commands.recordExchangeRate(
      'ws',
      s,
      _entry('1.06'),
      spaceCurrency: 'EUR',
    );
    expect(first?.revision, 1);
    final second = await commands.recordExchangeRate(
      'ws',
      s,
      _entry('1.0657'),
      spaceCurrency: 'EUR',
    );
    expect(second?.revision, 2);
    expect(second?.fxRate.rate, ExactDecimal.parse('1.0657'));
    expect(
      (await repo.fetchExchangeRate('ws', 'b-chf'))?.entry.rate,
      ExactDecimal.parse('1.0657'),
    );
    // Same currency as the space: nothing is sent.
    expect(
      await commands.recordExchangeRate(
        'ws',
        s,
        _entry('1'),
        spaceCurrency: 'CHF',
      ),
      isNull,
    );
    // Approved, its recorded rate is fixed.
    final approved = FakePurchaseRepository()
      ..add(_francDraft(state: PurchaseState.approved));
    final a = (await approved.fetchDetail('ws', 'b-chf')).summary;
    approved.rememberRate(
      PurchaseSummary(
        id: a.id,
        kind: a.kind,
        state: PurchaseState.pending,
        category: a.category,
        reference: a.reference,
        currency: a.currency,
      ),
      _entry('1.06'),
    );
    expect(
      () => approved.recordExchangeRate('ws', 'b-chf', _entry('1.07')),
      throwsStateError,
    );
  });

  group('on screen', () {
    Widget app(FakePurchaseRepository repo) => _scope([
      purchaseRepositoryProvider.overrideWithValue(repo),
      memberLabelsProvider.overrideWithValue({}),
      enabledFeatureKeysProvider.overrideWithValue({
        foreignCurrencyPurchasesKey,
      }),
      spaceCurrencyProvider.overrideWithValue('EUR'),
    ]);

    Future<void> pickDay(WidgetTester tester) async {
      await tester.ensureVisible(
        find.byKey(const ValueKey('purchase-fx-date')),
      );
      await tester.tap(find.byKey(const ValueKey('purchase-fx-date')));
      await _step(tester);
      await tester.tap(find.text('OK'));
      await _step(tester);
    }

    Future<void> pickSource(WidgetTester tester) async {
      await tester.ensureVisible(
        find.byKey(const ValueKey('purchase-fx-source')),
      );
      await tester.tap(find.byKey(const ValueKey('purchase-fx-source')));
      await _step(tester);
      await tester.tap(find.text('Applied by the bank').last);
      await _step(tester);
    }

    testWidgets('a bill in francs is not saved without its rate; with it, '
        'the draft keeps both', (tester) async {
      final repo = FakePurchaseRepository();
      await tester.pumpWidget(app(repo));
      await _step(tester);
      await tester.tap(find.byKey(const ValueKey('purchase-add-bill')));
      await _step(tester);
      await tester.tap(find.byKey(const ValueKey('purchase-currency')));
      await _step(tester);
      await tester.tap(find.text('CHF').last);
      await _step(tester);
      await tester.enterText(
        find.byKey(const ValueKey('purchase-gross')),
        '480',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('purchase-save')));
      await tester.tap(find.byKey(const ValueKey('purchase-save')));
      await _step(tester);
      expect(find.byKey(const ValueKey('purchase-invalid')), findsOneWidget);
      expect(await repo.fetchPurchases('ws'), isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('purchase-fx-rate')),
        '1,0657',
      );
      await pickSource(tester);
      await pickDay(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('purchase-save')));
      await tester.tap(find.byKey(const ValueKey('purchase-save')));
      await _step(tester);
      final saved = (await repo.fetchPurchases('ws')).single;
      expect(saved.currency, 'CHF');
      final rate = await repo.fetchExchangeRate('ws', saved.id);
      expect(rate?.entry.rate, ExactDecimal.parse('1.0657'));
      expect(rate?.entry.source, 'bank');
      expect(rate?.functionalCurrency, 'EUR');
    });

    testWidgets('a bill in francs without a rate says so; the rate entered '
        'on it is shown', (tester) async {
      final repo = FakePurchaseRepository()..add(_francDraft());
      await tester.pumpWidget(app(repo));
      await _step(tester);
      await tester.tap(find.byKey(const ValueKey('purchase-b-chf')));
      await _step(tester);
      expect(
        find.textContaining('No exchange rate is recorded'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('purchase-fx-edit')),
      );
      await tester.tap(find.byKey(const ValueKey('purchase-fx-edit')));
      await _step(tester);
      // Nothing entered: refused on screen, nothing recorded.
      await tester.tap(find.byKey(const ValueKey('purchase-fx-save')));
      await _step(tester);
      expect(find.byKey(const ValueKey('purchase-fx-invalid')), findsOneWidget);
      expect(await repo.fetchExchangeRate('ws', 'b-chf'), isNull);

      await tester.enterText(
        find.byKey(const ValueKey('purchase-fx-rate')),
        '1.0657',
      );
      await pickSource(tester);
      await pickDay(tester);
      await tester.tap(find.byKey(const ValueKey('purchase-fx-save')));
      await _step(tester);
      expect((await repo.fetchExchangeRate('ws', 'b-chf'))?.revision, 1);
      expect(find.textContaining('1 CHF = 1.0657 EUR'), findsOneWidget);
    });
  });
}
