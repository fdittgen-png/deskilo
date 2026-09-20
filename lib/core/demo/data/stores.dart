// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ADR 0028 (#1373) — the in-memory stores the Demo environment runs on:
// preferences, the active workspace, the cache, the badge, the files.
// Moved out of test/helpers/mock_providers.dart so Demo can mount them;
// the suite reaches them through the same import as before.

import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:deskilo/features/workspace/domain/workspace_import.dart';
import 'dart:typed_data' show Uint8List;
import 'package:deskilo/features/workspace/domain/workspace_export_bundle.dart';
import 'dart:async';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/badge/app_badge.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/scan/front_camera.dart';
import 'package:deskilo/core/storage/active_workspace_store.dart';

/// In-memory [CacheStore] so widget tests never touch the filesystem.
class InMemoryCacheStore implements CacheStore {
  final Map<String, CacheEntry> entries = {};

  @override
  Future<CacheEntry?> get(String key) async => entries[key];

  @override
  Future<void> put(String key, Object? payload,
      {required Duration ttl}) async {
    entries[key] =
        // Real clock on purpose: freshness is measured against the wall
        // clock inside CacheStore, so a pinned storedAt would make every
        // entry read as expired.
        CacheEntry(payload: payload, storedAt: DateTime.now(), ttl: ttl);
  }

  @override
  Future<void> invalidatePrefix(String prefix) async {
    entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<int> evictExpired() async {
    final before = entries.length;
    entries.removeWhere((_, e) => e.age > e.ttl * 3);
    return before - entries.length;
  }
}

/// In-memory [FrontCameraStore] so widget tests never touch
/// SharedPreferences; front camera by default, like production.
/// #780 — the device's chosen Supabase endpoint; null = the app's own.
class InMemoryBackendSettingsStore implements BackendSettingsStore {
  BackendEndpoint? value;

  @override
  Future<BackendEndpoint?> read() async => value;

  @override
  Future<void> write(BackendEndpoint? endpoint) async => value = endpoint;
}

class InMemoryFrontCameraStore implements FrontCameraStore {
  /// Null = never chosen (#773): the surface's own default applies.
  bool? value;

  @override
  Future<bool?> read() async => value;

  @override
  Future<void> write(bool enabled) async => value = enabled;
}

/// In-memory [ActiveWorkspaceStore] so widget tests never touch
/// SharedPreferences platform channels.
class InMemoryActiveWorkspaceStore implements ActiveWorkspaceStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? workspaceId) async => value = workspaceId;
}

/// In-memory [DefaultWorkspaceStore] (#322) so widget tests never touch
/// SharedPreferences.
class InMemoryDefaultWorkspaceStore implements DefaultWorkspaceStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? workspaceId) async => value = workspaceId;
}

/// App-icon badge fake (#426): records every count written.
class FakeAppBadge implements AppBadge {
  final counts = <int>[];

  @override
  Future<void> update(int count) async => counts.add(count);
}

/// #1310 — a workspace's stored files, keyed by path under its prefix.
class FakeWorkspaceFiles implements WorkspaceFilesRepository {
  FakeWorkspaceFiles([Map<String, List<int>>? files]) : files = files ?? {};
  final Map<String, List<int>> files;
  @override
  Future<List<String>> listFiles(String workspaceId) async =>
      files.keys.toList()..sort();
  @override
  Future<Uint8List> download(String workspaceId, String path) async =>
      Uint8List.fromList(files[path]!);
}

/// #1373 — the configuration import and export, in memory.
///
/// Demo has no server to import into, so this keeps the tree the session
/// exported and hands it back: enough for the journey that shows what an
/// export looks like, and nothing that could reach a project.
class InMemoryWorkspaceImport implements WorkspaceImportRepository {
  final Map<String, Map<String, Object?>> configurations = {};
  final List<String> importedPlans = [];

  @override
  Future<void> importFloorPlan(String workspaceId, WorkspaceXmlData data) async {
    importedPlans.add(workspaceId);
  }

  @override
  Future<Map<String, Object?>> exportConfiguration(String workspaceId) async =>
      configurations[workspaceId] ?? const {};

  @override
  Future<void> importConfiguration(
      String workspaceId, Map<String, Object?> configuration) async {
    configurations[workspaceId] = configuration;
  }
}
