// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/l10n/lexicon.dart';
import '../../../../core/share/file_sharer.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../events/providers/event_providers.dart';
import '../../../money/presentation/batch_cover.dart';
import '../../../plan/providers/accessory_providers.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../domain/space_code_entries.dart';
import '../../domain/space_codes_pdf.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_xml.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/space_codes_options_dialog.dart';
import 'workspace_settings_host.dart';
import 'workspace_settings_reports.dart';

/// #2494 — the settings screen's files of the space itself: the XML
/// backup (#164) and the space QR sheet, and what a restore or a reset
/// makes every plan surface read again.
class WorkspaceSettingsBackup {
  const WorkspaceSettingsBackup(this.host);

  final WorkspaceSettingsHost host;

  BuildContext get context => host.context;
  WidgetRef get ref => host.ref;

  /// Serializes the workspace settings + every level's floor plan + the
  /// accessory catalog and seat assignments (v2, #180) to the versioned
  /// XML format (#164) and hands it to the system share sheet as a `.xml`
  /// file — same seam the bill PDF export uses (#133).
  Future<void> exportXml(Workspace workspace) async {
    final context = this.context;
    final l10n = context.l10n;
    await host.runTool('workspace XML export failed', () async {
          // #1012 — every export leaves a trace of its start and its end, so a
          // silent device tells its story; the save is bounded, so a bridge
          // that never answers becomes an error instead of a frozen screen.
          TraceLogger.instance.log(TraceLevel.info, 'workspace',
              'xml export started for ${workspace.id}');
          final levels = await ref.read(levelsProvider.future);
          final plans = [
            for (final level in levels)
              (
                level: level,
                plan: await ref.read(floorPlanProvider(level.id).future),
              ),
          ];
          // Inactive entries included — a backup must be complete (#180).
          final accessories =
              await ref.read(accessoriesProvider(includeInactive: true).future);
          final seatAccessories = await ref.read(seatAccessoriesProvider.future);
          // #916 — the configuration section and the plan's references
          // by name, when the feature is on.
          final transfer = await readXmlConfiguration(ref, workspace.id);
          final xml = buildWorkspaceXml(
            configuration: transfer.configuration,
            siteNames: transfer.siteNames,
            vatRateLabels: transfer.vatRateLabels,
            workspace: workspace,
            levels: plans,
            accessories: accessories,
            seatAccessories: seatAccessories,
          );
          final bytes = utf8.encode(xml);
          final fileName = workspaceXmlFileName(workspace.name);
          final path = await ref
              .read(fileSaverProvider)(bytes: bytes, fileName: fileName)
              .timeout(const Duration(seconds: 30));
          TraceLogger.instance.log(TraceLevel.info, 'workspace',
              'xml export saved: ${path ?? '(no path)'} (${bytes.length} bytes)');
          if (!context.mounted) return;
          announceSaved(
            context,
            l10n,
            path,
            action: SnackBarAction(
              key: const ValueKey('workspace-settings-share'),
              label: l10n.commonShare,
              onPressed: () => ref.read(fileSharerProvider)(
                bytes: bytes,
                fileName: fileName,
                mimeType: 'application/xml',
              ),
            ),
          );
    });
  }

  /// Prints the space QR sheet (field request): one card per desk,
  /// office, level and chair, in an A4 grid — saved to Downloads.
  /// #584 — the owner first picks the card size (S/M/L) and which
  /// information rides each card (printed AND embedded in the QR).
  Future<void> exportSpaceCodes(Workspace workspace) async {
    final context = this.context;
    final l10n = context.l10n;
    final options = await showDialog<SpaceCodesOptions>(
      context: context,
      builder: (_) => const SpaceCodesOptionsDialog(),
    );
    if (options == null || !context.mounted) return;
    await host.runTool('space codes export failed', () async {
        // #671 — cover wording and images come from report management.
        final cover = await batchCover(context, ref, docId: 'space_codes', data: {
          'workspace': workspace.name,
          'issued': DateFormat.yMMMMd().format(ref.read(clockProvider).now()),
        });
        if (!context.mounted || cover == null) return;
        // #1277 — capture localized space nouns before reading the entries.
        final kindLevel = lexiconText(context,
            key: 'spaceKindLevel', fallback: l10n.spaceKindLevel);
        final kindOffice = lexiconText(context,
            key: 'spaceKindOffice',
            fallback: l10n.spaceKindOffice);
        final kindDesk = lexiconText(context,
            key: 'spaceKindDesk', fallback: l10n.spaceKindDesk);
        final kindSeat = lexiconText(context,
            key: 'spaceKindSeat', fallback: l10n.spaceKindSeat);
        final levels = await ref.read(levelsProvider.future);
        final entries = buildSpaceCodeEntries(
          workspaceId: workspace.id,
          workspaceName: workspace.name,
          plans: [
            for (final level in levels)
              (level, await ref.read(floorPlanProvider(level.id).future)),
          ],
          info: options.info,
          kindLabels: (
            level: kindLevel,
            office: kindOffice,
            desk: kindDesk,
            seat: kindSeat,
          ),
        );
        if (!context.mounted || ref.read(currentWorkspaceProvider).value?.id != workspace.id) return;
        if (entries.isEmpty) {
          if (!context.mounted) return;
          AppSnack.info(
            context,
            l10n.planNoLevels,
          );
          return;
        }
        final regular =
            await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        final bytes = await buildSpaceCodesPdf(
          workspaceName: workspace.name,
          entries: entries,
          baseFont: pw.Font.ttf(regular),
          boldFont: pw.Font.ttf(bold),
          size: options.size,
          qrSize: options.qrSize,
          coverContinuation: cover.continuation,
          pageLabel: l10n.invoicePdfPage,
          coverHeader: cover.header,
          coverBody: cover.body,
          coverFooter: cover.footer,
        );
        final path = await ref.read(fileSaverProvider)(
          bytes: bytes,
          fileName: '${safeFileSlug(workspace.name)}-space-codes.pdf',
        );
        if (!context.mounted) return;
        announceSaved(context, l10n, path);
    });
  }
}

/// What an XML import may have rewritten, read again.
void refreshImported(WidgetRef ref, {required bool configuration}) {
  ref
    ..invalidate(myWorkspacesProvider)
    ..invalidate(levelsProvider)
    ..invalidate(floorPlanProvider)
    ..invalidate(targetNamesProvider)
    // #180 — the import may have upserted the catalog and re-created
    // every seat assignment.
    ..invalidate(accessoriesProvider)
    ..invalidate(seatAccessoriesProvider);
  if (configuration) refreshConfigurationReads(ref);
}

/// Refresh every surface that read the data a reset (0039) deleted.
void refreshAfterReset(WidgetRef ref) {
  ref
    ..invalidate(levelsProvider)
    ..invalidate(floorPlanProvider)
    ..invalidate(targetNamesProvider)
    ..invalidate(accessoriesProvider)
    ..invalidate(seatAccessoriesProvider)
    ..invalidate(myWorkspacesProvider);
  invalidateBookingData(ref);
}
