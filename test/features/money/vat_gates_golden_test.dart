// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2479 (C3 of #2476) -- the small-business thresholds, the tax point policy,
// the issuing gate and the e-invoicing mandate calendar come from the tax
// reference store. `golden/vat_gates_golden.json` was captured from the Dart
// constants BEFORE they were deleted: every answer, country by country. The
// store reproduces it exactly, and the golden stays -- except where a gate
// was opened on purpose: the United States (0440, #2362) read `unsupported`
// and now read their own profile.
//
// The second group is the history rule: change the data, regenerate nothing,
// compare -- a change from a day changes the answers from that day only.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/einvoice_mandates.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_clauses.dart';
import 'package:deskilo/features/money/domain/small_business_threshold.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:deskilo/features/money/presentation/widgets/small_business_notice.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

TaxReferenceRow _row(String domain, String country, String key, String from,
        Map<String, Object?> value, {String? to}) =>
    TaxReferenceRow.fromJson({
      'domain': domain,
      'country': country,
      'key': key,
      'valid_from': from,
      'valid_to': to,
      'value': value,
      'source': 'a test',
      'confirmed': true,
    });

/// The installed snapshot with the open version of one value closed on
/// [from] and [value] starting then -- what `set_tax_reference` does.
TaxReferenceSet _changed(String domain, String country, String key, String from,
    Map<String, Object?> value) {
  return TaxReferenceSet([
    for (final r in ActiveTaxReference.current.rows)
      if (r.domain.wire == domain && r.country == country && r.key == key && r.validTo == null)
        r.closedOn(from)
      else
        r,
    _row(domain, country, key, from, value),
  ]);
}

void main() {
  final golden = jsonDecode(
    File('test/features/money/golden/vat_gates_golden.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final countries = (golden['countries'] as List).cast<String>();

  test('the tax point policy and basis equal the old switch for every country', () {
    final expected = golden['taxPoint'] as Map<String, dynamic>;
    for (final c in countries) {
      final p = vatTaxPointPolicy(c);
      expect({
        'standard': p.standard.name,
        'invoiceOption': p.invoiceOption,
        'cashOption': p.cashOption,
        'cashBackstop': p.cashBackstop.name,
        'basis': {
          for (final o in [null, ...VatTaxPointOption.values])
            '${o?.name}': '${vatTaxPointBasis(c, o).rule.name}/${vatTaxPointBasis(c, o).backstop.name}',
        },
        'options': [for (final o in p.options) o.name],
      }, expected[c], reason: c);
    }
  });

  test('the small-business alerts equal the old rows, for every country, currency and turnover', () {
    final expected = golden['thresholds'] as Map<String, dynamic>;
    for (final MapEntry(key: k, value: byTurnover) in expected.entries) {
      final [country, currency] = k.split('/');
      for (final MapEntry(key: t, value: want) in (byTurnover as Map<String, dynamic>).entries) {
        final got = [
          for (final a in smallBusinessAlerts(
              country: country, currency: currency, turnoverCents: int.parse(t)))
            '${a.threshold.country}|${a.threshold.cents}|${a.threshold.effect.name}|'
                '${a.threshold.source}|${a.threshold.confirmed}|${a.level.name}',
        ];
        // The source names the row's origin now: compare everything but it.
        String strip(String s) {
          final parts = s.split('|');
          return [...parts.take(3), ...parts.skip(4)].join('|');
        }
        expect(got.map(strip).toList(), (want as List).cast<String>().map(strip).toList(),
            reason: '$k @ $t');
      }
    }
  });

  test('the mandate calendar, its warnings and the national channels equal the old ones', () {
    final mandates = golden['mandates'] as Map<String, dynamic>;
    for (final c in countries) {
      expect([for (final m in mandatesFor(c)) '${m.duty.name}|${m.from.toIso8601String()}'],
          mandates[c], reason: c);
    }
    for (final MapEntry(key: k, value: want) in (golden['warnings'] as Map<String, dynamic>).entries) {
      final [country, day] = k.split('/');
      expect([for (final m in mandateWarnings(country, DateTime.parse(day))) '${m.duty.name}|${m.from.toIso8601String()}'],
          want, reason: k);
    }
    expect(nationalChannelRequired.toList()..sort(), golden['nationalChannelRequired']);
    expect(mandateWarningCountries.toList()..sort(), golden['mandateWarningCountries']);
  });

  test('the issuing gate profile of every country and capacity equals the old rule', () {
    for (final MapEntry(key: k, value: want) in (golden['profiles'] as Map<String, dynamic>).entries) {
      final [country, capacity] = k.split('/');
      expect(
        legalProfileOf(LegalClauseSnapshot(
          sellerCountry: country,
          buyerCapacity: CustomerCapacity.values.byName(capacity),
        )).name,
        want,
        reason: k,
      );
    }
  });

  group('history is frozen: change the data, regenerate nothing, compare', () {
    test('a new threshold from a day changes the alert from that day only', () {
      final set = _changed('threshold', 'DE', 'small_business_next_year', '2027-01-01',
          {'cents': 5000000, 'effect': 'next_year', 'currency': 'EUR'});
      List<SmallBusinessAlert> at(String day) => smallBusinessAlerts(
            country: 'DE', currency: 'EUR', turnoverCents: 3000000, asOf: day, reference: set);
      expect(at('2026-12-31').single.level, ThresholdLevel.passed);
      expect(at('2027-01-01'), isEmpty);
      expect(smallBusinessAlerts(country: 'DE', currency: 'EUR', turnoverCents: 3000000)
          .single.threshold.cents, 2500000);
    });

    test('a changed tax point policy applies from its day', () {
      final set = _changed('tax_point', 'DE', 'policy', '2027-01-01', {
        'standard': 'receipt', 'invoice_option': false, 'cash_option': true, 'cash_backstop': 'none',
      });
      expect(vatTaxPointPolicy('DE', asOf: '2026-12-31', reference: set).standard,
          VatTaxPointRule.servicePeriod);
      expect(vatTaxPointPolicy('DE', asOf: '2027-01-01', reference: set).standard,
          VatTaxPointRule.receipt);
    });

    test('a mandate date that slips is a new version, the old one stays on record', () {
      final set = _changed('mandate', 'DE', 'issue_all', '2026-06-01',
          {'duty': 'issue_all', 'from': '2029-01-01'});
      expect(mandatesFor('DE', asOf: '2026-05-31', reference: set).last.from, DateTime(2028));
      expect(mandatesFor('DE', asOf: '2026-06-01', reference: set).last.from, DateTime(2029));
    });

    test('a gate turned off from a day refuses from that day; a channel refuses whatever supported says', () {
      final off = _changed('issuing_gate', 'GB', 'gate', '2027-01-01', {
        'supported': false, 'requires_tax_number': false, 'national_channel_required': false, 'currency': 'GBP',
      });
      expect(off.issuesFor('GB', asOf: '2026-12-31'), isTrue);
      expect(off.issuesFor('GB', asOf: '2027-01-01'), isFalse);
      final channel = _changed('issuing_gate', 'FR', 'gate', '2027-01-01', {
        'supported': true, 'requires_tax_number': false, 'national_channel_required': true,
      });
      expect(channel.issuesFor('FR', asOf: '2027-01-01'), isFalse);
      expect(channel.nationalChannelCountries(asOf: '2027-01-01'), contains('FR'));
      expect(ActiveTaxReference.current.issuesFor('FR'), isTrue);
    });
  });

  group('the small-business notice follows the version in force today', () {
    Future<void> pump(WidgetTester tester) async {
      final money = FakeMoneyRepository()
        ..invoices.add(Invoice(
          id: 'inv', workspaceId: 'ws-1', memberId: 'member-1', number: 'inv',
          issuedAt: DateTime(kTestNow.year, 3, 4), period: '2026-03', title: 'inv',
          lines: const [], totalCents: 2600000, currency: 'EUR', memberName: 'Kunde',
          memberAddress: '', workspaceName: 'Demo', workspaceAddress: '',
          issuerName: '', signature: '',
          vatTotals: const [
            InvoiceVatTotal(percent: 0, category: 'E', grossCents: 2600000, netCents: 2600000, vatCents: 0),
          ],
        ));
      await tester.pumpWidget(ProviderScope(
        overrides: standardTestOverrides(money: money, workspace: FakeWorkspaceRepository.withWorkspace()),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SmallBusinessNotice(exempt: true, country: 'DE', currency: 'EUR'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a higher figure from today silences the alert; one from tomorrow does not', (tester) async {
      final previous = ActiveTaxReference.current;
      addTearDown(() => ActiveTaxReference.install(previous));
      final today = kTestNow.toIso8601String().substring(0, 10);
      final tomorrow = kTestNow.add(const Duration(days: 1)).toIso8601String().substring(0, 10);
      const higher = {'cents': 9000000, 'effect': 'next_year', 'currency': 'EUR'};

      ActiveTaxReference.install(_changed('threshold', 'DE', 'small_business_next_year', tomorrow, higher));
      await pump(tester);
      expect(find.byKey(const ValueKey('small-business-notice')), findsOneWidget);

      ActiveTaxReference.install(previous);
      ActiveTaxReference.install(_changed('threshold', 'DE', 'small_business_next_year', today, higher));
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(find.byKey(const ValueKey('small-business-notice')), findsNothing);
    });
  });
}
