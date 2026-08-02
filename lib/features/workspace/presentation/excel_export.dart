// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_saver.dart';
import '../../../core/files/xlsx.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/guarded.dart';
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
import '../domain/workspace.dart';
import '../domain/workspace_excel.dart';
import '../providers/workspace_providers.dart';

/// Gathers everything the workbook needs and hands the bytes to the
/// local-save seam (#395). Orchestration only — the tab layout lives in
/// [buildWorkspaceExcelExport], the file format in `core/files/xlsx.dart`,
/// so both stay pure and testable without a widget in sight.
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
          .fetchProfiles([for (final m in members) m.userId]);
      final money = ref.read(moneyRepositoryProvider);
      final events = await ref
          .read(eventRepositoryProvider)
          .fetchEvents(workspace.id, limit: 10000);
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

      final stamp = ref
          .read(clockProvider)
          .now()
          .toIso8601String()
          .substring(0, 10);
      final path = await ref.read(fileSaverProvider)(
        bytes: buildXlsx(sheets),
        fileName: 'deskilo-export-${workspace.inviteCode}-$stamp.xlsx',
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
