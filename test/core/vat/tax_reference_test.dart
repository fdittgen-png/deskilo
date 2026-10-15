// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 -- the pure side of the tax reference store: a date resolves to
// the version in force, a wrong shape is refused with a readable error,
// the bundled copy stands in for an unreachable installation, and a past
// date keeps answering what it answered before a change (history is frozen).
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/demo/data/tax_reference_repository.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:flutter_test/flutter_test.dart';

TaxReferenceRow _rate(String from, double percent, {String? to}) =>
    TaxReferenceRow(
      country: 'FR',
      key: 'standard',
      validFrom: from,
      validTo: to,
      value: RateValue(
          label: 'Standard $percent %', percent: percent, group: 'standard', category: 'S'),
      source: 'test',
      confirmed: true,
    );

void main() {
  test('a date resolves to the version in force; the boundary day is the new one', () {
    final set = TaxReferenceSet([
      _rate('2020-01-01', 20, to: '2027-01-01'),
      _rate('2027-01-01', 21),
    ]);
    String percentOn(String d) =>
        (set.on(d).lookup(TaxDomain.rate, 'FR', 'standard')!.value as RateValue)
            .percent
            .toString();
    expect(percentOn('2026-12-31'), '20.0');
    expect(percentOn('2027-01-01'), '21.0');
    expect(set.on('2019-12-31').rows, isEmpty);
  });

  test('a country row wins over the shared * row for the same key', () {
    TaxReferenceRow text(String country, String t) => TaxReferenceRow(
          country: country,
          key: 'exempt',
          validFrom: '1900-01-01',
          value: ExemptionTextValue(regime: 'exempt', text: t),
          source: 's',
          confirmed: false,
        );
    final set = TaxReferenceSet([text('*', 'shared'), text('FR', 'own')]);
    expect((set.lookup(TaxDomain.mention, 'fr', 'exempt')!.value as ExemptionTextValue).text, 'own');
    expect((set.lookup(TaxDomain.mention, 'DE', 'exempt')!.value as ExemptionTextValue).text, 'shared');
  });

  test('a wrong shape is refused with the row and the field named', () {
    expect(
      () => TaxReferenceRow.fromJson({
        'domain': 'rate',
        'country': 'FR',
        'key': 'standard',
        'valid_from': '2026-01-01',
        'value': {'label': 'x', 'percent': 'twenty', 'group': 'standard', 'category': 'S'},
        'source': 's',
      }),
      throwsA(isA<JsonShapeException>()
          .having((e) => e.toString(), 'message', contains('percent'))),
    );
    expect(() => TaxDomain.fromWire('nonsense'), throwsA(isA<JsonShapeException>()));
  });

  test('the revision changes when a version is added', () {
    final one = TaxReferenceSet([_rate('2020-01-01', 20)]);
    final two = TaxReferenceSet([_rate('2020-01-01', 20, to: '2027-01-01'), _rate('2027-01-01', 21)]);
    expect(one.revision, isNot(two.revision));
    expect(one.revision, TaxReferenceSet([_rate('2020-01-01', 20)]).revision);
  });

  test('the revision changes when a planned version is confirmed or withdrawn (#2565)',
      () async {
    const planned = TaxReferenceRow(
      id: 'p',
      country: 'FR',
      key: 'standard',
      validFrom: '2028-01-01',
      value: RateValue(
          label: 'Standard 21 %', percent: 21, group: 'standard', category: 'S'),
      source: 'Bill',
      confirmed: false,
    );
    final store = FakeTaxReferenceRepository(
        [_rate('2020-01-01', 20, to: '2028-01-01'), planned]);
    final planned0 = (await store.load()).revision;
    await store.confirm('p');
    final confirmed = (await store.load()).revision;
    expect(confirmed, isNot(planned0));
    final other = FakeTaxReferenceRepository(
        [_rate('2020-01-01', 20, to: '2028-01-01'), planned]);
    await other.withdraw('p', 'vote failed');
    expect((await other.load()).revision, isNot(planned0));
    expect((await other.load()).rows.single.validTo, isNull);
    expect(() => store.withdraw('p', 'x'), throwsStateError,
        reason: 'a confirmed version is only superseded');
  });

  test('the bundled copy stands in when the installation cannot answer', () async {
    final server = FakeTaxReferenceRepository([_rate('2020-01-01', 20)])
      ..failWith = Exception('offline');
    final bundled = TaxReferenceSet([_rate('2020-01-01', 19)]);
    final source = BundledFallbackTaxReferenceSource(server, () async => bundled);
    final set = await source.load(domain: TaxDomain.rate, country: 'FR');
    expect(set.origin, TaxReferenceOrigin.bundle);
    expect((set.rows.single.value as RateValue).percent, 19);
  });

  test('no server and no bundle is a typed failure, never an empty answer', () async {
    final server = FakeTaxReferenceRepository()..failWith = Exception('offline');
    final source = BundledFallbackTaxReferenceSource(server, () async => throw Exception('no asset'));
    await expectLater(source.load(), throwsA(isA<TaxReferenceUnavailable>()));
  });

  test('a malformed answer from the server is not hidden by the bundle', () async {
    final server = FakeTaxReferenceRepository()..failWith = const JsonShapeException('r', 'k', 'String', 'null');
    final source = BundledFallbackTaxReferenceSource(server, () async => const TaxReferenceSet([]));
    await expectLater(source.load(), throwsA(isA<JsonShapeException>()));
  });

  test('history is frozen: a new version never changes what a past date resolves to', () async {
    final store = FakeTaxReferenceRepository([_rate('2020-01-01', 20)]);
    String past(TaxReferenceSet s) =>
        (s.on('2026-06-01').lookup(TaxDomain.rate, 'FR', 'standard')!.value as RateValue).label;
    final before = past(await store.load());
    await store.setVersion(const TaxVersionDraft(domain: TaxDomain.rate,
      country: 'FR',
      key: 'standard',
      value: RateValue(label: 'Standard 21 %', percent: 21, group: 'standard', category: 'S'),
      source: 'law',
      confirmed: true,
      validFrom: '2027-01-01',
    ));
    final after = await store.load();
    expect(past(after), before);
    expect((after.on('2027-02-01').lookup(TaxDomain.rate, 'FR', 'standard')!.value as RateValue).percent, 21);
    expect(after.history(TaxDomain.rate, 'FR', 'standard'), hasLength(2));
  });
}
