// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- the Demo's units behind the port, with the server's own rules (0951): the 13 built-ins first, a unit created and
// edited by code, a retried request that answers once, a built-in and a used unit that keep their factor, a reduced fraction,
// and the refusals in the stock configuration's field and reason.
import 'package:deskilo/core/demo/data/demo_workspace_units.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:deskilo/features/stock/providers/workspace_units_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ws = 'ws-1';

Matcher _refused(String field, String reason) =>
    isA<StockConfigRefused>().having((e) => e.field, 'field', field).having((e) => e.reason, 'reason', reason);

void main() {
  late DemoWorkspaceUnits units;
  var request = 0;
  String next() => 'req-${request++}';

  setUp(() => units = DemoWorkspaceUnits());

  test('a business has the 13 built-ins, in the server\'s order and with its factors', () async {
    final all = await units.units(_ws);
    expect(all.map((u) => u.code), ['piece', 'g', 'kg', 'ml', 'cl', 'l', 'mm', 'cm', 'm', 'km', 'm2', 'min', 'h']);
    expect(all.every((u) => u.builtIn && u.label == null), isTrue);
    final km = all.firstWhere((u) => u.code == 'km');
    expect([km.dimension, km.factorNum, km.factorDen, km.unEceCode], [UnitDimension.length, 1000, 1, 'KMT']);
    final mm = all.firstWhere((u) => u.code == 'mm');
    expect([mm.factorNum, mm.factorDen], [1, 1000]);
  });

  test('another business has its own list', () async {
    await units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'drum', label: 'Cable drum', dimension: UnitDimension.length, factorNum: 50));
    expect((await units.units(_ws)).map((u) => u.code), contains('drum'));
    expect((await units.units('ws-2')).map((u) => u.code), isNot(contains('drum')));
  });

  test('a unit is created, its fraction is reduced, and it is edited while unused', () async {
    final drum = await units.save(_ws,
        requestId: next(), draft: const MeasureUnitDraft(code: 'drum', label: 'Cable drum', dimension: UnitDimension.length, factorNum: 100, factorDen: 2));
    expect([drum.factorNum, drum.factorDen, drum.builtIn], [50, 1, false]);
    final edited = await units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'drum', factorNum: 60));
    expect([edited.factorNum, edited.label], [60, 'Cable drum']);
  });

  test('a retried request answers once, and another content under its id is refused', () async {
    const draft = MeasureUnitDraft(code: 'drum', label: 'Cable drum', dimension: UnitDimension.length, factorNum: 50);
    final first = await units.save(_ws, requestId: 'same', draft: draft);
    final again = await units.save(_ws, requestId: 'same', draft: draft);
    expect(identical(first, again), isTrue);
    expect(() => units.save(_ws, requestId: 'same', draft: const MeasureUnitDraft(code: 'drum', label: 'Another')),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', 'DKG07')));
  });

  test('a malformed unit is refused by field and reason', () async {
    Future<void> save(MeasureUnitDraft d) => units.save(_ws, requestId: next(), draft: d);
    expect(save(const MeasureUnitDraft(code: 'Bad Code', label: 'x', dimension: UnitDimension.length, factorNum: 1)), throwsA(_refused('code', 'code_malformed')));
    expect(save(const MeasureUnitDraft(code: 'bad', label: 'x', factorNum: 1)), throwsA(_refused('dimension', 'dimension_invalid')));
    expect(save(const MeasureUnitDraft(code: 'bad', label: 'x', dimension: UnitDimension.length, factorNum: 0)), throwsA(_refused('factor', 'factor_invalid')));
    expect(save(const MeasureUnitDraft(code: 'bad', dimension: UnitDimension.length, factorNum: 1)), throwsA(_refused('label', 'label_required')));
    expect(save(MeasureUnitDraft(code: 'bad', label: 'x' * 41, dimension: UnitDimension.length, factorNum: 1)), throwsA(_refused('label', 'too_long')));
    expect(save(const MeasureUnitDraft(code: 'bad', label: 'x', dimension: UnitDimension.length, factorNum: 1, unEceCode: 'toolong')),
        throwsA(_refused('un_ece_code', 'ece_invalid')));
  });

  test('a built-in keeps its factor but takes a word of the business\'s own, and gives it back', () async {
    await expectLater(units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'km', factorNum: 999)), throwsA(_refused('factor', 'registry_unit')));
    final named = await units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'km', label: 'Kilometre'));
    expect([named.label, named.factorNum], ['Kilometre', 1000]);
    final back = await units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'km', clearLabel: true));
    expect(back.label, isNull);
  });

  test('a used unit keeps its dimension and factor, may be renamed, and cannot be archived', () async {
    await units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'drum', label: 'Cable drum', dimension: UnitDimension.length, factorNum: 50));
    units.usedBy = (workspaceId, code) => code == 'drum';
    await expectLater(units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'drum', factorNum: 60)), throwsA(_refused('factor', 'unit_in_use')));
    expect((await units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'drum', label: 'Drum of cable'))).label, 'Drum of cable');
    await expectLater(units.archive(_ws, requestId: next(), code: 'drum', archived: true), throwsA(_refused('archived', 'unit_in_use')));
  });

  test('one code keeps one meaning: a code an item already uses for its packaging cannot be a unit', () async {
    units.packages = (workspaceId, code) => code == 'box';
    await expectLater(
      units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'box', label: 'Box', dimension: UnitDimension.count, factorNum: 6)),
      throwsA(_refused('code', 'code_duplicate')),
    );
    expect((await units.units(_ws)).map((u) => u.code), isNot(contains('box')));
    expect((await units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'crate', label: 'Crate', dimension: UnitDimension.count, factorNum: 6))).code, 'crate');
  });

  test('an unused unit is archived and shown again; an unknown one is refused', () async {
    await units.save(_ws, requestId: next(), draft: const MeasureUnitDraft(code: 'drum', label: 'Cable drum', dimension: UnitDimension.length, factorNum: 50));
    await units.archive(_ws, requestId: next(), code: 'drum', archived: true);
    expect((await units.units(_ws)).firstWhere((u) => u.code == 'drum').archived, isTrue);
    await units.archive(_ws, requestId: next(), code: 'drum', archived: false);
    expect((await units.units(_ws)).firstWhere((u) => u.code == 'drum').archived, isFalse);
    await expectLater(units.archive(_ws, requestId: next(), code: 'ghost', archived: true), throwsA(_refused('unit', 'unit_unknown')));
  });

  test('the Demo\'s overrides answer the port: the provider lists the built-ins of the business it is asked about', () async {
    final container = ProviderContainer(overrides: demoOverrides(DemoFixture.build()));
    addTearDown(container.dispose);
    final list = await container.read(workspaceUnitListProvider(demoLondonSpaceId).future);
    expect(list.map((u) => u.code).take(3), ['piece', 'g', 'kg']);
    expect(list, hasLength(13));
  });
}
