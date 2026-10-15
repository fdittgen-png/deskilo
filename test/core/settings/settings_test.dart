// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2484 -- the pure side of the settings registry: a typed read from the
// effective values (no caller-side fallback), the definition's own check of
// type, bounds and security floor, the bundled-registry fallback, and the
// in-memory store's precedence workspace > platform > default.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/demo/data/settings_repository.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

const _days = SettingDefinition(
  key: 'dunning.first_after_days',
  type: SettingType.integer,
  defaultValue: 14,
  min: 1,
  max: 365,
  unit: 'days',
  group: 'dunning',
  scopes: {SettingScope.platform, SettingScope.workspace},
  editPermission: 'workspaceSettings',
);

const _lockout = SettingDefinition(
  key: 'security.lockout_minutes',
  type: SettingType.duration,
  defaultValue: 15,
  min: 5,
  max: 120,
  unit: 'minutes',
  group: 'security',
  scopes: {SettingScope.platform},
  floor: 10,
);

const _guardrail = SettingDefinition(
  key: 'security.max_pin_length',
  type: SettingType.integer,
  defaultValue: 8,
  unit: 'digits',
  group: 'security',
  scopes: {SettingScope.platform},
  editable: false,
  note: 'The badge reader accepts at most eight digits.',
);

void main() {
  test('a typed read gives the effective value; a duration reads as a Duration', () {
    final set = SettingsSet.defaults([_days, _lockout]);
    expect(set.read<int>('dunning.first_after_days'), 14);
    expect(set.read<Duration>('security.lockout_minutes'), const Duration(minutes: 15));
    expect(set.originOf('dunning.first_after_days'), SettingOrigin.registryDefault);
  });

  test('an unknown key and a wrong type are defects, never a silent fallback', () {
    final set = SettingsSet.defaults([_days]);
    expect(() => set.read<int>('nope.nothing'), throwsA(isA<UnknownSetting>()));
    expect(() => set.read<bool>('dunning.first_after_days'), throwsA(isA<SettingTypeMismatch>()));
    expect(() => set.read<Duration>('dunning.first_after_days'), throwsA(isA<SettingTypeMismatch>()));
  });

  test('the definition refuses what the server refuses: type, bounds, floor', () {
    expect(_days.check(30), isNull);
    expect(_days.check(0), SettingProblem.belowMin);
    expect(_days.check(366), SettingProblem.aboveMax);
    expect(_days.check('ten'), SettingProblem.notANumber);
    expect(_days.check(1.5), SettingProblem.notANumber);
    expect(_lockout.check(9), SettingProblem.belowFloor, reason: 'the floor beats the minimum');
    expect(_lockout.check(10), isNull);
  });

  test('a wire row of the wrong shape is refused with the field named', () {
    expect(
      () => SettingDefinition.fromJson({'key': 'a.b', 'type': 'int', 'default_value': 'x', 'group_key': 'g', 'scopes': ['platform']}),
      throwsA(isA<JsonShapeException>().having((e) => e.toString(), 'm', contains('default_value'))),
    );
    expect(() => SettingType.fromWire('weird'), throwsA(isA<JsonShapeException>()));
  });

  test('my_settings parses into a snapshot with origins and a revision', () {
    final set = SettingsSet.parse([
      {
        'key': 'dunning.first_after_days', 'type': 'int', 'default_value': 14,
        'min': 1, 'max': 365, 'unit': 'days', 'group_key': 'dunning',
        'scopes': ['platform', 'workspace'], 'edit_permission': 'workspaceSettings',
        'floor_value': null, 'editable': true, 'choices': null,
        'value': 30, 'origin': 'workspace',
      },
    ]);
    expect(set.read<int>('dunning.first_after_days'), 30);
    expect(set.originOf('dunning.first_after_days'), SettingOrigin.workspace);
    expect(set.revision, isNot(SettingsSet.defaults([_days]).revision));
  });

  test('the bundled registry stands in with defaults when the installation is away', () async {
    final store = FakeSettingsRepository([_days])..failWith = Exception('offline');
    final source = BundledFallbackSettingsSource(store, () async => [_days]);
    final set = await source.load('ws-1');
    expect(set.read<int>('dunning.first_after_days'), 14);
    final none = BundledFallbackSettingsSource(store, () async => throw Exception('no asset'));
    await expectLater(none.load('ws-1'), throwsA(isA<SettingsUnavailable>()));
  });

  test('precedence: workspace over platform over the default; history keeps the closed version', () async {
    final store = FakeSettingsRepository([_days]);
    Future<int> now(String? ws) async => (await store.load(ws)).read<int>('dunning.first_after_days');
    expect(await now('ws-1'), 14);
    await store.setValue(key: 'dunning.first_after_days', value: 21);
    expect(await now('ws-1'), 21, reason: 'the platform default reaches the workspace');
    await store.setValue(workspaceId: 'ws-1', key: 'dunning.first_after_days', value: 10);
    expect(await now('ws-1'), 10);
    expect(await now('ws-2'), 21, reason: 'another workspace keeps the platform value');
    await store.setValue(workspaceId: 'ws-1', key: 'dunning.first_after_days', value: 12);
    final history = await store.history('ws-1', 'dunning.first_after_days');
    expect(history.map((v) => v.value), [12, 10]);
    expect(history.last.validTo, isNotNull, reason: 'the first version was closed, not edited');
  });

  test('the store refuses a guardrail, an out-of-range value and a scope the key lacks', () async {
    final store = FakeSettingsRepository([_days, _lockout, _guardrail]);
    await expectLater(store.setValue(key: 'security.max_pin_length', value: 6), throwsArgumentError);
    await expectLater(store.setValue(key: 'dunning.first_after_days', value: 0), throwsArgumentError);
    await expectLater(store.setValue(key: 'security.lockout_minutes', value: 9), throwsArgumentError);
    await expectLater(
      store.setValue(workspaceId: 'ws-1', key: 'security.lockout_minutes', value: 30),
      throwsArgumentError,
      reason: 'a workspace cannot write a platform-only setting',
    );
    expect(store.writes, isEmpty);
  });
}
