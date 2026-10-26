// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2372 — the Xero targets: one per region, each signed in to and delivered
// as documents, offered where its organisations are (the EU target in every
// member state of the tax reference, nowhere else), and the adapter knows
// each target by the same countries as the descriptors.
import 'dart:io';

import 'package:deskilo/core/vat/place_of_supply.dart';
import 'package:deskilo/features/money/domain/accounting_capability.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/workspace/domain/feature_countries.dart';
import 'package:flutter_test/flutter_test.dart';

const _ids = {'xero_gb', 'xero_ca', 'xero_us', 'xero_eu'};

List<AccountingTarget> get _xero => [
  for (final t in accountingTargets)
    if (t.id.startsWith('xero_')) t,
];

void main() {
  test('the four regions are API targets that take documents through a '
      'sign-in, implemented against the named API', () {
    expect(_xero.map((t) => t.id).toSet(), _ids);
    for (final t in _xero) {
      expect(t.transport, AccountingTransport.api, reason: t.id);
      expect(t.payload, AccountingPayload.documents, reason: t.id);
      expect(t.format, isNull, reason: t.id);
      expect(t.connectsBy, {AccountingAuthKind.oauth2}, reason: t.id);
      expect(t.taxCodeModel, TaxCodeModel.perRate, reason: t.id);
      expect(t.capability.state, QualificationState.implemented, reason: t.id);
      expect(t.capability.specification, contains('Xero Accounting API 2.0'));
      expect(t.capability.obligations, {Obligation.targetAcceptance});
      expect(t.operations, contains(AccountingOperation.sale));
      expect(
        t.operations,
        isNot(contains(AccountingOperation.attachment)),
        reason: 'no PDF is attached yet',
      );
    }
  });

  test('each region is offered where its organisations are', () {
    String? xeroIn(String country) =>
        targetsFor(country)
            .where((t) => t.id.startsWith('xero_'))
            .singleOrNull
            ?.id;
    expect(xeroIn('GB'), 'xero_gb');
    expect(xeroIn('CA'), 'xero_ca');
    expect(xeroIn('US'), 'xero_us');
    for (final member in euMemberStates) {
      expect(xeroIn(member), 'xero_eu', reason: member);
    }
    expect(xeroIn('CH'), isNull);
    expect(xeroIn('NO'), isNull);
  });

  test('the adapter knows each region by the descriptor\'s countries', () {
    final adapter = File('supabase/functions/_shared/accounting_xero.ts')
        .readAsStringSync();
    final table = adapter.substring(adapter.indexOf('ORGANISATION_COUNTRIES'));
    final countries = {
      for (final m in RegExp(
        r'^  ([a-z_]+): \["([A-Z]{2})"\]',
        multiLine: true,
      ).allMatches(table.substring(0, table.indexOf('};'))))
        m[1]!: {m[2]!},
    };
    final eu = RegExp(r'EU_TARGET = "([a-z_]+)"').firstMatch(adapter)![1]!;
    expect(
      {
        ...countries,
        eu: {featureCountriesEu},
      },
      {for (final t in _xero) t.id: t.countries},
    );
  });

  test('the delivery runner dispatches every region to the Xero adapter', () {
    final runner = File('supabase/functions/accounting-connect/deliver.ts')
        .readAsStringSync();
    final dispatched = {
      for (final m in RegExp(
        r'^  (xero_[a-z]+): xeroAccounting,$',
        multiLine: true,
      ).allMatches(runner))
        m[1]!,
    };
    expect(dispatched, _ids);
  });
}
