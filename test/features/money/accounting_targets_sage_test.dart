// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 — one Sage per product: Sage Business Cloud Accounting one target
// per region, signed in to and delivered as documents; Sage 100 and Sage 50
// in France pointing to the FEC and Sage 50 / 100 in Germany to DATEV, and
// the export sheet saying so; Sage 50 Canada, Sage 200 and Sage Intacct
// waiting for a specification, visibly. The adapter and the runner know
// each region by the descriptor's country.
import 'dart:io';

import 'package:deskilo/features/money/domain/accounting_capability.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/presentation/accounting_export_sage.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _regions = {
  'sage_business_cloud_gb': 'GB',
  'sage_business_cloud_ie': 'IE',
  'sage_business_cloud_ca': 'CA',
  'sage_business_cloud_us': 'US',
  'sage_business_cloud_fr': 'FR',
  'sage_business_cloud_de': 'DE',
  'sage_business_cloud_es': 'ES',
};

AccountingTarget _target(String id) =>
    accountingTargets.firstWhere((t) => t.id == id);

void main() {
  test('Sage Business Cloud: one API target per region, a sign-in, '
      'documents, implemented against the named API', () {
    for (final MapEntry(key: id, value: country) in _regions.entries) {
      final t = _target(id);
      expect(t.transport, AccountingTransport.api, reason: id);
      expect(t.payload, AccountingPayload.documents, reason: id);
      expect(t.format, isNull, reason: id);
      expect(t.countries, {country}, reason: id);
      expect(t.connectsBy, {AccountingAuthKind.oauth2}, reason: id);
      expect(t.runnerDelivers, isTrue, reason: id);
      expect(t.capability.state, QualificationState.implemented, reason: id);
      expect(t.capability.specification, contains('Sage Accounting API v3.1'));
      expect(t.capability.obligations, {Obligation.targetAcceptance});
      expect(t.customerIdRule.maxLength, 8, reason: id);
    }
  });

  test('the adapter knows each region by the descriptor\'s country', () {
    final adapter = File(
      'supabase/functions/_shared/accounting_sage.ts',
    ).readAsStringSync();
    final table = adapter.substring(adapter.indexOf('BUSINESS_COUNTRIES'));
    final countries = {
      for (final m in RegExp(
        r'^  ([a-z_]+): "([A-Z]{2})",',
        multiLine: true,
      ).allMatches(table.substring(0, table.indexOf('};'))))
        m[1]!: m[2]!,
    };
    expect(countries, _regions);
    expect(adapter, contains('CONTACT_REFERENCE_LENGTH = 8;'));
  });

  test('the runner dispatches every region to the Sage adapter', () {
    final runner = File(
      'supabase/functions/accounting-connect/deliver.ts',
    ).readAsStringSync();
    for (final id in _regions.keys) {
      expect(runner, contains('  $id: sageAccounting,'), reason: id);
    }
  });

  test('Sage 100 and Sage 50 in France import the FEC, Sage in Germany '
      'and Austria DATEV; neither writes a file of its own', () {
    expect(importRoutesFor('FR')['fec']!.map((t) => t.id), [
      'sage100_fr',
      'sage50_fr',
    ]);
    for (final country in ['DE', 'AT']) {
      expect(importRoutesFor(country)['datev']!.map((t) => t.id), ['sage_de']);
    }
    expect(importRoutesFor('GB'), isEmpty);
    for (final id in ['sage100_fr', 'sage50_fr', 'sage_de']) {
      expect(_target(id).format, isNull, reason: id);
      expect(formatsFor('FR').map((f) => f.id), isNot(contains(id)));
    }
  });

  test('choosing a Sage of France or Germany is told which file to take', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final fr = importNotices(l10n, 'FR');
    expect(fr, hasLength(1));
    expect(fr.single, contains('Sage 100 Comptabilité'));
    expect(fr.single, contains(l10n.invoiceExportFec));
    final de = importNotices(l10n, 'DE').single;
    expect(de, contains('Sage 50 / Sage 100'));
    expect(de, contains(l10n.invoiceExportDatev));
    expect(importNotices(l10n, 'GB'), isEmpty);
  });

  test('Sage 50 Canada, Sage 200 and Sage Intacct wait for a '
      'specification and write nothing', () {
    for (final id in ['sage50_ca', 'sage200', 'sage_intacct']) {
      final t = _target(id);
      expect(t.capability.state, QualificationState.specificationNeeded);
      expect(t.capability.producible, isFalse, reason: id);
      expect(t.format, isNull, reason: id);
      expect(t.runnerDelivers, isFalse, reason: id);
    }
    expect(targetsFor('CA').map((t) => t.id), contains('sage50_ca'));
  });
}
