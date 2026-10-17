// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_workspace_files.dart';
import '../domain/workspace_export_bundle.dart';
import 'workspace_providers.dart';

part 'workspace_files_providers.g.dart';

/// #1310 — the workspace's stored files, for the export.
@Riverpod(keepAlive: true)
WorkspaceFilesRepository workspaceFilesRepository(Ref ref) =>
    SupabaseWorkspaceFiles(ref.watch(selectedWorkspaceClientProvider));
