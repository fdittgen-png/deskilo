// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_workspace_files.dart';
import '../domain/workspace_export_bundle.dart';

part 'workspace_files_providers.g.dart';

/// #1310 — the workspace's stored files, for the export.
@Riverpod(keepAlive: true)
WorkspaceFilesRepository workspaceFilesRepository(Ref ref) =>
    SupabaseWorkspaceFiles(Supabase.instance.client);
