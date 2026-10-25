// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the accounting target registry: every target is decided, a file
// target writes its own format, the countries live on the target, and the
// formats the sheet offers are the file targets of the registry.
import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/features/money/domain/accounting_capability.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
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

  test('the FEC target names the client code of an auxiliary account', () {
    final rule = accountingTargets.firstWhere((t) => t.id == 'fec').customerIdRule;
    expect(rule.maxLength, 13);
    expect(rule.charset, isNotNull);
  });
}
