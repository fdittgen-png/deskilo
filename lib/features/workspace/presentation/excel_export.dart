// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/schema_version.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/domain/workspace_event.dart';
import '../../events/providers/event_providers.dart';
import '../../money/providers/money_providers.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../../profile/domain/profile.dart';
import '../../profile/providers/profile_providers.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../domain/member.dart';
import '../domain/workspace.dart';
import '../domain/workspace_excel.dart';
import '../domain/workspace_export_bundle.dart';
import '../providers/workspace_files_providers.dart';
import '../providers/workspace_providers.dart';

/// Gathers everything the workbook needs and hands the bytes to the
/// local-save seam (#395). Orchestration only — the tab layout lives in
/// [buildWorkspaceExcelExport], the ZIP and its manifest in
/// [buildWorkspaceExportZip] (#1310), so both stay pure and testable
/// without a widget in sight.
Future<void> exportWorkspaceExcel(
  BuildContext context,
  WidgetRef ref,
  Workspace workspace,
) async {
  final l10n = AppLocalizations.of(context);
  await runGuarded(
    context,
    domain: 'workspace',
    message: 'excel data export failed',
    errorText:
        l10n?.workspaceGenericError ?? 'Something went wrong. Please try again.',
    action: () async {
      final levels = await ref.read(levelsProvider.future);
      final plans = <String, FloorPlan>{
        for (final level in levels)
          level.id: await ref.read(floorPlanProvider(level.id).future),
      };
      final members = await ref.read(workspaceMembersProvider.future);
      final profiles = await ref
          .read(profileRepositoryProvider)
          .fetchProfiles(accountIdsOf(members));
      final money = ref.read(moneyRepositoryProvider);
      final events = await ref
          .read(eventRepositoryProvider)
          .fetchEvents(workspace.id, limit: 0);
      final features = await ref.read(enabledFeaturesProvider.future);
      final transmissions =
          await money.fetchInvoiceTransmissions(workspace.id);

      final sheets = buildWorkspaceExcelExport(
        workspace: workspace,
        enabledFeatures: {for (final f in features) f.dbKey},
        levels: levels,
        plansByLevel: plans,
        members: members,
        profilesByUserId: <String, Profile>{
          for (final p in profiles) p.id: p,
        },
        reservations: await ref
            .read(reservationRepositoryProvider)
            .fetchAllForExport(workspace.id),
        ledger: await money.fetchWorkspaceLedger(workspace.id),
        pendingEvents: [
          for (final e in events)
            if (e.status == EventStatus.pending) e,
        ],
        paymentIntents: await money.fetchPaymentIntents(workspace.id),
        services:
            await money.fetchServices(workspace.id, includeInactive: true),
        invoices: await money.fetchInvoices(workspace.id),
        transmissionsByInvoice: {
          for (final entry in transmissions.entries)
            entry.key: entry.value.sentAt,
        },
      );

      // #1310 — the space's own stored files travel with its rows. A
      // file that cannot be read fails the export: a copy that silently
      // lacks a plan background is the short export this issue is about.
      final filesRepo = ref.read(workspaceFilesRepositoryProvider);
      final files = <ExportedFile>[
        for (final path in await filesRepo.listFiles(workspace.id))
          (path: path, bytes: await filesRepo.download(workspace.id, path)),
      ];
      // #1312 — which schema the rows came from. Unreadable is recorded as
      // null rather than guessed.
      int? schemaVersion;
      try {
        schemaVersion = await ref.read(schemaVersionSourceProvider).read();
      } on SchemaVersionUnavailable catch (e, st) {
        TraceLogger.instance.warn('workspace',
            'export: schema version unreadable, manifest records null',
            error: e, stackTrace: st);
      }

      final now = ref.read(clockProvider).now();
      final stamp = now.toIso8601String().substring(0, 10);
      final path = await ref.read(fileSaverProvider)(
        bytes: buildWorkspaceExportZip(
          workspaceId: workspace.id,
          schemaVersion: schemaVersion,
          createdAt: now,
          sheets: sheets,
          files: files,
        ),
        fileName: 'deskilo-export-${workspace.inviteCode}-$stamp.zip',
      );
      if (!context.mounted) return;
      if (path == null) {
        AppSnack.error(context, l10n?.commonSaveFailed ?? 'Could not save.');
      } else {
        AppSnack.success(
          context,
          l10n?.commonSavedTo(path) ?? 'Saved to $path',
        );
      }
    },
  );
}
