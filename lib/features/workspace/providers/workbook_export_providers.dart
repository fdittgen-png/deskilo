// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/files/file_saver.dart';
import '../application/template_workbook.dart';
import '../data/supabase_workbook_origin_repository.dart';
import '../domain/workbook_origin.dart';
import 'workspace_providers.dart';

part 'workbook_export_providers.g.dart';

@Riverpod(keepAlive: true)
WorkbookOriginRepository workbookOriginRepository(Ref ref) =>
    SupabaseWorkbookOriginRepository(Supabase.instance.client);

/// Keep an imperative export alive without widget listeners, but invalidate
/// it permanently when its account or repository changes, including A→B→A.
@Riverpod(keepAlive: true)
TemplateWorkbookExport templateWorkbookExport(Ref ref) {
  final account = ref.watch(currentAccountIdProvider);
  var current = true;
  ref.onDispose(() => current = false);
  return TemplateWorkbookExport(
    ref.watch(workspaceRepositoryProvider), ref.watch(fileSaverProvider),
    origin: ref.watch(workbookOriginRepositoryProvider),
    isCurrent: () => current && ref.mounted && ref.read(currentAccountIdProvider) == account,
  );
}
