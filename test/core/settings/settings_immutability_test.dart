// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2589 C1 -- a settings snapshot is a value: copied on construction,
// unmodifiable afterwards, versioned twice (values and validation rules) and
// captured with the identity it was read for, before any await.
import 'dart:async';

import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/core/settings/settings_capture.dart';
import 'package:flutter_test/flutter_test.dart';

SettingDefinition _def({
  String key = 'dunning.first_after_days',
  Set<SettingScope>? scopes,
  List<String> choices = const [],
  num? max = 365,
  num? floor,
}) =>
    SettingDefinition(
      key: key,
      type: SettingType.integer,
      defaultValue: 14,
      min: 1,
      max: max,
      floor: floor,
      unit: 'days',
      group: 'dunning',
      scopes: scopes ?? {SettingScope.platform, SettingScope.workspace},
      choices: choices,
    );

class _Source implements SettingsSource {
  _Source(this.byWorkspace);
  final Map<String?, SettingsSet> byWorkspace;
  final gates = <String?, Completer<void>>{};

  @override
  Future<SettingsSet> load(String? workspaceId) async {
    await gates[workspaceId]?.future;
    return byWorkspace[workspaceId]!;
  }

  @override
  Future<List<SettingVersion>> history(String? workspaceId, String key) async => [];
}

SettingsSet _set(int days, {num? max = 365}) {
  final d = _def(max: max);
  return SettingsSet({d.key: d}, {d.key: days});
}

void main() {
  test('mutating the originals cannot change a definition or a set', () {
    final scopes = <SettingScope>{SettingScope.platform};
    final choices = <String>['a', 'b'];
    final d = SettingDefinition(
      key: 'k',
      type: SettingType.choice,
      defaultValue: 'a',
      group: 'g',
      scopes: scopes,
      choices: choices,
    );
    scopes.add(SettingScope.workspace);
    choices.add('c');
    expect(d.scopes, {SettingScope.platform});
    expect(d.choices, ['a', 'b']);
    expect(d.check('c'), SettingProblem.notAChoice);

    final definitions = {d.key: d};
    final effective = <String, Object>{'k': 'a'};
    final origins = {'k': SettingOrigin.platform};
    final set = SettingsSet(definitions, effective, origins: origins);
    definitions.clear();
    effective['k'] = 'b';
    origins['k'] = SettingOrigin.workspace;
    expect(set.read<String>('k'), 'a');
    expect(set.originOf('k'), SettingOrigin.platform);
    expect(set.definitions.keys, ['k']);
  });

  test('public and nested getters cannot be mutated', () {
    final d = _def(choices: const ['x']);
    expect(() => d.scopes.add(SettingScope.platform), throwsUnsupportedError);
    expect(() => d.choices.add('y'), throwsUnsupportedError);
    final set = _set(14);
    expect(() => set.effective['dunning.first_after_days'] = 1, throwsUnsupportedError);
    expect(() => set.definitions.remove('dunning.first_after_days'), throwsUnsupportedError);
    expect(() => set.origins['x'] = SettingOrigin.platform, throwsUnsupportedError);
  });

  test('a parsed definition is frozen too', () {
    final d = SettingsSet.parse([
      {
        'key': 'k',
        'type': 'int',
        'default_value': 1,
        'group_key': 'g',
        'scopes': ['platform'],
        'value': 3,
      },
    ]).definitions['k']!;
    expect(() => d.scopes.add(SettingScope.workspace), throwsUnsupportedError);
  });

  test('a changed value changes the data revision, not the schema revision', () {
    final a = _set(14);
    final b = _set(30);
    expect(a.revision, isNot(b.revision));
    expect(a.schemaRevision, b.schemaRevision);
    expect(a.fingerprint, isNot(b.fingerprint));
  });

  test('a changed bound, floor or choice changes the schema revision', () {
    final base = _set(14);
    expect(_set(14, max: 400).schemaRevision, isNot(base.schemaRevision));
    final floorDef = _def(floor: 7);
    final withFloor = SettingsSet({floorDef.key: floorDef}, {floorDef.key: 14});
    expect(withFloor.schemaRevision, isNot(base.schemaRevision));
    expect(withFloor.revision, base.revision);
    expect(
      _def(choices: const ['a']).validationFingerprint,
      isNot(_def(choices: const ['a', 'b']).validationFingerprint),
    );
  });

  test('equivalent definitions in another insertion order share one fingerprint', () {
    final a = _def(key: 'a.one', choices: const ['x', 'y']);
    final b = _def(key: 'b.two');
    final one = SettingsSet({a.key: a, b.key: b}, {a.key: 1, b.key: 2});
    final other = SettingsSet(
      {
        b.key: b,
        'a.one': _def(
          key: 'a.one',
          scopes: {SettingScope.workspace, SettingScope.platform},
          choices: const ['y', 'x'],
        ),
      },
      {b.key: 2, a.key: 1},
    );
    expect(other.schemaRevision, one.schemaRevision);
    expect(other.revision, one.revision);
    expect(other.fingerprint, one.fingerprint);
  });

  test('two interleaved captures keep their own settings; equal text never merges them', () async {
    final source = _Source({'ws-a': _set(14), 'ws-b': _set(14)})
      ..gates['ws-a'] = Completer<void>()
      ..gates['ws-b'] = Completer<void>();
    const idA = SettingsIdentity(installation: 'https://one', workspaceId: 'ws-a', principal: 'u1');
    const idB = SettingsIdentity(installation: 'https://one', workspaceId: 'ws-b', principal: 'u1');
    final a = captureSettings(source, idA);
    final b = captureSettings(source, idB);
    // W-B answers first, then W-A; neither result moves to the other.
    source.gates['ws-b']!.complete();
    final capB = await b;
    source.gates['ws-a']!.complete();
    final capA = await a;
    expect(capA.identity, idA);
    expect(capB.identity, idB);
    // Identical values and revision text on two workspaces: still two keys.
    expect(capA.settings.fingerprint, capB.settings.fingerprint);
    expect(capA.cacheKey, isNot(capB.cacheKey));
    expect(capA, isNot(capB));
    // Same workspace on another installation or for another person differs.
    final elsewhere = SettingsCapture(
      const SettingsIdentity(installation: 'https://two', workspaceId: 'ws-a', principal: 'u1'),
      capA.settings,
    );
    final otherPerson = SettingsCapture(
      const SettingsIdentity(installation: 'https://one', workspaceId: 'ws-a', principal: 'u2'),
      capA.settings,
    );
    expect(elsewhere.cacheKey, isNot(capA.cacheKey));
    expect(otherPerson.cacheKey, isNot(capA.cacheKey));
  });

  test('a capture of different settings under the same identity differs', () {
    const id = SettingsIdentity(installation: 'i', workspaceId: 'w', principal: 'p');
    expect(SettingsCapture(id, _set(14)).cacheKey, isNot(SettingsCapture(id, _set(30)).cacheKey));
    expect(SettingsCapture(id, _set(14)), SettingsCapture(id, _set(14)));
  });
}
