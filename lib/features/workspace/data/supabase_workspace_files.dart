// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_export_bundle.dart';

/// #1310 — the workspace's files, read from the `floor-plans` bucket the
/// 0036/0215 policies scope to the workspace's first path segment.
class SupabaseWorkspaceFiles implements WorkspaceFilesRepository {
  const SupabaseWorkspaceFiles(this._client);

  final SupabaseClient _client;
  static const _bucket = 'floor-plans';

  /// Storage lists one folder level at a time; a page holds at most this.
  static const _page = 1000;

  @override
  Future<List<String>> listFiles(String workspaceId) async {
    final out = <String>[];
    Future<void> walk(String relative) async {
      final prefix = relative.isEmpty ? workspaceId : '$workspaceId/$relative';
      for (var offset = 0;; offset += _page) {
        final entries = await _client.storage.from(_bucket).list(
              path: prefix,
              searchOptions: SearchOptions(limit: _page, offset: offset),
            );
        for (final e in entries) {
          if (e.name.isEmpty) continue;
          final child = relative.isEmpty ? e.name : '$relative/${e.name}';
          // A folder has no id: storage synthesises it from the prefixes.
          if (e.id == null) {
            await walk(child);
          } else {
            out.add(child);
          }
        }
        if (entries.length < _page) break;
      }
    }

    await walk('');
    return out..sort();
  }

  @override
  Future<Uint8List> download(String workspaceId, String path) =>
      _client.storage.from(_bucket).download('$workspaceId/$path');
}
