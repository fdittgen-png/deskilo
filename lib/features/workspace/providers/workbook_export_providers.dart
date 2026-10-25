// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/files/file_saver.dart';
import '../application/bi_snapshot_export.dart';
import '../application/template_workbook.dart';
import '../data/supabase_bi_export_repository.dart';
import '../data/supabase_workbook_origin_repository.dart';
import '../domain/bi_report_snapshot.dart';
import '../domain/workbook_origin.dart';
import 'workspace_providers.dart';

part 'workbook_export_providers.g.dart';

@Riverpod(keepAlive: true)
WorkbookOriginRepository workbookOriginRepository(Ref ref) =>
    SupabaseWorkbookOriginRepository(ref.watch(selectedWorkspaceClientProvider));

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

/// #2581 — the export read of a report's figures.
@Riverpod(keepAlive: true)
BiExportRepository biExportRepository(Ref ref) =>
    SupabaseBiExportRepository(ref.watch(selectedWorkspaceClientProvider));

/// #2581 — one export's snapshot, dropped when its account is no longer the
/// one signed in (the same fence as the template workbook's).
@Riverpod(keepAlive: true)
BiSnapshotExport biSnapshotExport(Ref ref) {
  final account = ref.watch(currentAccountIdProvider);
  var current = true;
  ref.onDispose(() => current = false);
  return BiSnapshotExport(
    ref.watch(biExportRepositoryProvider),
    isCurrent: () => current && ref.mounted && ref.read(currentAccountIdProvider) == account,
  );
}
