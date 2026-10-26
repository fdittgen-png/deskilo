// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the accounting target registry: every target is decided, a file
// target writes its own format, the countries live on the target, and the
// formats the sheet offers are the file targets of the registry.
import 'dart:io';

import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/features/money/domain/accounting_capability.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Producible targets whose external specification nobody has named yet.
/// It may only shrink: name the reviewed spec, version included, in
/// `accountingCapabilities` and take the target out.
const _specificationNotNamed = {'datev', 'sage50', 'ch_kmu'};

void main() {
  test('every target has a reviewed qualification', () {
    for (final t in accountingTargets) {
      expect(
        t.capability.state,
        isNot(QualificationState.unsupported),
        reason: t.id,
      );
    }
  });

  test('a producible target names its specification, or is listed '
      'as not named yet', () {
    final unnamed = {
      for (final t in accountingTargets)
        if (t.capability.producible && t.capability.specification.isEmpty) t.id,
    };
    expect(unnamed, _specificationNotNamed);
  });

  test('a producible file target writes its own format; ids are unique', () {
    for (final t in accountingTargets) {
      if (t.transport == AccountingTransport.file && t.capability.producible) {
        expect(t.format?.id, t.id);
      }
      // A target nobody can produce yet writes nothing.
      if (!t.capability.producible) expect(t.format, isNull, reason: t.id);
    }
    expect(
      accountingTargets.map((t) => t.id).toSet(),
      hasLength(accountingTargets.length),
    );
  });

  test('the sheet offers the file targets of the country, in order', () {
    for (final country in ['FR', 'DE', 'GB', 'ZZ']) {
      expect(formatsFor(country).map((f) => f.id), [
        for (final t in targetsFor(country))
          if (t.transport == AccountingTransport.file && t.format != null)
            t.id,
      ], reason: country);
    }
  });

  test('no supported country is offered nothing at all', () {
    final uncovered = [
      for (final country in CountryCatalog.countries)
        if (targetsFor(country.code).isEmpty) country.code,
    ];
    expect(uncovered, isEmpty);
  });

  test('a national target is offered at home only', () {
    expect(targetsFor('DE').map((t) => t.id), contains('datev'));
    expect(targetsFor('FR').map((t) => t.id), isNot(contains('datev')));
    expect(targetsFor('ZZ').map((t) => t.id), contains('generic_journal_csv'));
  });

  // #2376 — the French platforms: Pennylane through its API, Cegid Quadra
  // and EBP named with the FEC as their working route until their own
  // import formats are specified.
  test('the French platforms are decided targets', () {
    final fr = {for (final t in targetsFor('FR')) t.id: t};
    expect(fr['pennylane_api']!.transport, AccountingTransport.api);
    expect(fr['pennylane_api']!.format, isNull);
    expect(fr['pennylane_api']!.capability.producible, isTrue);
    for (final id in ['cegid_quadra_ascii', 'ebp_import']) {
      expect(
        fr[id]!.capability.state,
        QualificationState.specificationNeeded,
        reason: id,
      );
    }
    expect(formatsFor('FR').map((f) => f.id), isNot(contains('pennylane_api')));
    expect(formatsFor('DE').map((f) => f.id), isNot(contains('ebp_import')));
  });

  // The descriptor says which targets take a sign-in; the edge function's
  // table says how. Neither may name a target the other does not.
  test('a producible API target says how it is connected, a file target '
      'never; a sign-in target is in the edge function\'s table, and the '
      'table names nothing else', () {
    for (final t in accountingTargets) {
      if (t.transport == AccountingTransport.file) {
        expect(t.connectsBy, isEmpty, reason: t.id);
      } else if (t.capability.producible) {
        expect(t.connectsBy, isNotEmpty, reason: t.id);
      }
    }
    final table = File(
      'supabase/functions/_shared/accounting_targets.ts',
    ).readAsStringSync();
    final body = table.substring(table.indexOf('oauthTargets'));
    final inTable = {
      for (final m in RegExp(r'^  ([a-z0-9_]+): \{', multiLine: true).allMatches(body))
        m[1]!,
    };
    expect(inTable, {
      for (final t in accountingTargets)
        if (t.connectsBy.contains(AccountingAuthKind.oauth2)) t.id,
    });
  });

  // The Pennylane adapter finds a company's journal by the code of the
  // posting's journal: the same codes as the app's.
  test('the Pennylane adapter reads the journals by the app\'s codes', () {
    final adapter = File(
      'supabase/functions/_shared/accounting_pennylane.ts',
    ).readAsStringSync();
    final table = adapter.substring(adapter.indexOf('JOURNAL_CODES'));
    final codes = {
      for (final m in RegExp(r'^  ([a-z]+): "([A-Z]+)",', multiLine: true)
          .allMatches(table.substring(0, table.indexOf('};'))))
        m[1]!: m[2]!,
    };
    expect(codes, {for (final j in PostingJournal.values) j.name: j.code});
  });

  // The QuickBooks adapter refuses a realm of another country than its
  // target's: the same countries as the descriptors.
  test('the QuickBooks adapter knows each QuickBooks target by its country', () {
    final adapter = File(
      'supabase/functions/_shared/accounting_quickbooks.ts',
    ).readAsStringSync();
    final table = adapter.substring(adapter.indexOf('REALM_COUNTRIES'));
    final countries = {
      for (final m in RegExp(r'^  ([a-z_]+): "([A-Z]{2})",', multiLine: true)
          .allMatches(table.substring(0, table.indexOf('};'))))
        m[1]!: m[2]!,
    };
    expect(countries, {
      for (final t in accountingTargets)
        if (t.id.startsWith('quickbooks_online_')) t.id: t.countries.single,
    });
    expect(countries, hasLength(3));
  });

  test('the FEC target names the client code of an auxiliary account', () {
    final rule = accountingTargets.firstWhere((t) => t.id == 'fec').customerIdRule;
    expect(rule.maxLength, 13);
    expect(rule.charset, isNotNull);
  });
}
