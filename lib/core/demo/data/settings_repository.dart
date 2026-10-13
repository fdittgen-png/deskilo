// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../settings/settings.dart';

/// #2484 -- the settings registry in memory, with the server's rules: the
/// type, bounds and floor are checked, a guardrail cannot be written, and a
/// workspace value beats a platform value beats the default.
class FakeSettingsRepository implements SettingsStore {
  FakeSettingsRepository(Iterable<SettingDefinition> definitions)
      : definitions = {for (final d in definitions) d.key: d},
        _loader = null;

  /// Demo: the registry is the one the app ships, read when first asked.
  FakeSettingsRepository.fromLoader(Future<List<SettingDefinition>> Function() loader)
      : definitions = {},
        _loader = loader;

  final Map<String, SettingDefinition> definitions;
  final Future<List<SettingDefinition>> Function()? _loader;

  Future<void> _ready() async {
    final loader = _loader;
    if (loader != null && definitions.isEmpty) {
      for (final d in await loader()) {
        definitions[d.key] = d;
      }
    }
  }

  /// Stored versions by `workspace-or-platform|key`, oldest first.
  final Map<String, List<SettingVersion>> versions = {};

  /// Makes [load] fail, to exercise the bundled registry.
  Object? failWith;

  /// Every `setValue` call, in order.
  final List<({String? workspaceId, String key, Object value})> writes = [];

  String _slot(String? ws, String key) => '${ws ?? 'platform'}|$key';

  Object? _open(String? ws, String key) {
    final list = versions[_slot(ws, key)];
    if (list == null) return null;
    for (final v in list.reversed) {
      if (v.validTo == null) return v.value;
    }
    return null;
  }

  @override
  Future<SettingsSet> load(String? workspaceId) async {
    await _ready();
    final failure = failWith;
    if (failure != null) {
      throw failure is Exception ? failure : Exception('$failure');
    }
    final effective = <String, Object>{};
    final origins = <String, SettingOrigin>{};
    for (final d in definitions.values) {
      final ws = workspaceId == null || !d.allows(SettingScope.workspace)
          ? null
          : _open(workspaceId, d.key);
      final platform = d.allows(SettingScope.platform) ? _open(null, d.key) : null;
      effective[d.key] = ws ?? platform ?? d.defaultValue;
      origins[d.key] = ws != null
          ? SettingOrigin.workspace
          : platform != null
              ? SettingOrigin.platform
              : SettingOrigin.registryDefault;
    }
    return SettingsSet(definitions, effective, origins: origins, revision: '${writes.length}');
  }

  @override
  Future<List<SettingVersion>> history(String? workspaceId, String key) async =>
      [...?versions[_slot(workspaceId, key)]].reversed.toList();

  @override
  Future<void> setValue({
    String? workspaceId,
    required String key,
    required Object value,
    String note = '',
  }) async {
    await _ready();
    final d = definitions[key];
    if (d == null) throw ArgumentError('unknown setting $key');
    if (!d.editable) throw ArgumentError('$key is a guardrail');
    final scope = workspaceId == null ? SettingScope.platform : SettingScope.workspace;
    if (!d.allows(scope)) throw ArgumentError('$key has no ${scope.wire} value');
    final problem = d.check(value);
    if (problem != null) throw ArgumentError('$key refused: ${problem.name}');
    writes.add((workspaceId: workspaceId, key: key, value: value));
    final list = versions.putIfAbsent(_slot(workspaceId, key), () => []);
    if (list.isNotEmpty && list.last.validTo == null) {
      if (list.last.value == value) return;
      final last = list.removeLast();
      list.add(SettingVersion(
        scope: last.scope,
        workspaceId: last.workspaceId,
        key: last.key,
        value: last.value,
        validFrom: last.validFrom,
        validTo: 'v${list.length + 1}',
        note: last.note,
      ));
    }
    list.add(SettingVersion(
      scope: scope,
      workspaceId: workspaceId,
      key: key,
      value: value,
      validFrom: 'v${list.length + 1}',
      note: note,
    ));
  }
}
