// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1884 A — the workspace feature keys the recorder accepts as a feature switch's target. #4408 — read from the
// registry itself, so a new flag is a target the moment it exists (it was a hand copy pinned equal to the enum). The
// recorder's action registry is a compile-time constant, so the set is one too: it reads the enum when it is asked.
import 'dart:collection';

import '../../workspace/domain/workspace_feature.dart';

/// #1884 A — the workspace feature keys a feature switch may name: the public product identifiers of
/// [WorkspaceFeature], as `workspaces.feature_flags` stores them.
const Set<String> workspaceFeatureKeys = _FeatureKeys();

/// The feature whose key is [key], or null when no feature has it.
WorkspaceFeature? workspaceFeatureOfKey(String key) => WorkspaceFeature.values.where((f) => f.dbKey == key).firstOrNull;

/// Every [WorkspaceFeature]'s key, unmodifiable.
class _FeatureKeys extends SetBase<String> {
  const _FeatureKeys();

  Set<String> get _keys => {for (final f in WorkspaceFeature.values) f.dbKey};

  @override
  bool contains(Object? element) => element is String && WorkspaceFeature.values.any((f) => f.dbKey == element);

  @override
  Iterator<String> get iterator => _keys.iterator;

  @override
  int get length => WorkspaceFeature.values.length;

  @override
  String? lookup(Object? element) => contains(element) ? element as String : null;

  @override
  Set<String> toSet() => _keys;

  @override
  bool add(String value) => throw UnsupportedError('the feature keys are the registry: they are not added to');

  @override
  bool remove(Object? value) => throw UnsupportedError('the feature keys are the registry: they are not removed from');
}
