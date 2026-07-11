// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_workspace_import_repository.dart';
import '../domain/workspace_import.dart';

part 'workspace_import_providers.g.dart';

/// Owner-only XML import boundary (#165); own file so the parallel
/// workspace features never contend on workspace_providers.dart.
@Riverpod(keepAlive: true)
WorkspaceImportRepository workspaceImportRepository(Ref ref) =>
    SupabaseWorkspaceImportRepository(Supabase.instance.client);
