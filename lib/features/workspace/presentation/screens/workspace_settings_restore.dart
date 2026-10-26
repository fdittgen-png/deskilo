// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_picker.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/retention_text.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/setup_journey_save.dart';
import '../../application/toggle_workspace_feature.dart';
import '../../application/workspace_backup_commands.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_import.dart';
import '../../domain/workspace_permission.dart';
import '../../domain/workspace_xml.dart';
import '../../domain/workspace_xml_configuration.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/configuration_transfer_prompt.dart';
import '../widgets/reset_confirm_dialog.dart';
import 'workspace_settings_backup.dart';
import 'workspace_settings_host.dart';

/// #2494 — the two settings tools that replace data: the XML restore
/// (#165) and the workspace reset (0039). A failed restore is reported
/// by the screen, which knows how far [XmlImportProgress] got.
class WorkspaceSettingsRestore {
  const WorkspaceSettingsRestore(this.host);

  final WorkspaceSettingsHost host;

  BuildContext get context => host.context;
  WidgetRef get ref => host.ref;

  /// Irreversible workspace reset (0039): a destructive dialog that unlocks
  /// its confirm button only once the owner types the exact confirmation
  /// phrase ("I agree"), then wipes all transactions + the floor plan while
  /// keeping settings and members.
  Future<void> resetWorkspace(Workspace workspace) async {
    final context = this.context;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ResetConfirmDialog(
        phrase: l10n.workspaceResetConfirmPhrase,
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await host.runTool('workspace reset failed', () async {
      try {
        await resetWorkspaceData(ref, workspace.id);
      } on Object catch (e, st) {
        // #2571 — the books still under retention: the server deleted
        // nothing and says until when, under which rule, or which hold.
        final kept = retentionRefusalOf(e);
        if (kept == null) Error.throwWithStackTrace(e, st);
        TraceLogger.instance.warn('workspace', 'workspace reset refused by retention', error: e, stackTrace: st);
        if (context.mounted) {
          final locale = Localizations.localeOf(context).toLanguageTag();
          AppSnack.error(context, l10n.retentionResetRefused(retentionAssessmentText(l10n, kept, locale)));
        }
        return;
      }
      refreshAfterReset(ref);
      if (!context.mounted) return;
      AppSnack.success(
        context,
        l10n.workspaceResetDone,
      );
    });
  }

  /// Owner-only XML import (#165): pick file → parse (typed errors) →
  /// client-side placement validation → preview + destructive confirm →
  /// transactional replace via the import RPC, settings via the existing
  /// owner writers. Throws what the server refused; [progress] says how
  /// far it got.
  Future<void> importXml(Workspace workspace, XmlImportProgress progress) async {
    final context = this.context;
    final read = await _readFile();
    if (read == null) return;
    final (content, data) = read;
    final choice = await _configurationChoice(data);
    if (choice == null) return;
    if (!await _confirm(data, choice)) return;
    if (!context.mounted) return;

    final planKept =
        await _applyConfigurationAndPlan(workspace, data, choice, progress);
    final brandRefused = await host.applyImportedSettings(
        workspace, data, progress,
        switchTransferOn: choice.switchOn);
    // #2868 — the file's <profile> becomes the space's setup journey.
    await saveImportedSetupProfile(ref,
        workspaceId: workspace.id, xml: content);
    refreshImported(ref, configuration: choice.apply);
    if (!context.mounted) return;
    // Re-seed the form so the imported settings show immediately.
    host.reseed();
    _announce(data, brandRefused: brandRefused, planKept: planKept);
  }

  /// The picked file, parsed and placement-checked; null when cancelled
  /// or refused (the refusal already told).
  Future<(String, WorkspaceXmlData)?> _readFile() async {
    final context = this.context;
    final l10n = context.l10n;
    final pick = ref.read(filePickerProvider);
    final file = await pick(XTypeGroup(
      // Acronym identical in every locale (IBAN precedent, #155); the
      // key exists so the parity gate covers the whole set.
      label: l10n.workspaceXmlFileTypeLabel,
      extensions: const ['xml'],
      mimeTypes: const ['application/xml', 'text/xml'],
    ));
    if (file == null) return null; // cancelled
    // Explicit UTF-8 decode: the export declares UTF-8 (#164), and
    // XFile.readAsString is not UTF-8-safe for data-backed files.
    final content = utf8.decode(await file.readAsBytes());
    if (!context.mounted) return null;

    final WorkspaceXmlData data;
    try {
      data = parseWorkspaceXml(content);
    } on WorkspaceXmlException catch (e, st) {
      TraceLogger.instance.error(
          'workspace', 'workspace XML import rejected: ${e.detail}',
          error: e, stackTrace: st);
      if (!context.mounted) return null;
      AppSnack.error(context, _xmlErrorMessage(l10n, e.error));
      return null;
    }

    // The editor's placement rules (spec §10) gate the preview: a file
    // whose plan the editor could never have drawn is rejected here.
    final invalid = validateWorkspaceXmlPlan(data);
    if (invalid != null) {
      TraceLogger.instance.error(
          'workspace',
          'workspace XML import plan invalid '
          '(${invalid.problem.name}): ${invalid.detail}');
      if (!context.mounted) return null;
      AppSnack.error(
        context,
        l10n.workspaceXmlErrorInvalidPlan,
      );
      return null;
    }
    return (content, data);
  }

  bool _transferOn() => ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.configurationTransfer);

  /// #916 — the configuration section applies when the feature is on;
  /// a v1/v2 file has none. #2331 — with the feature off it is no
  /// longer skipped in silence: the owner is asked first, and may
  /// switch the feature on for this import. Null when the owner
  /// cancelled.
  Future<({bool apply, bool switchOn})?> _configurationChoice(
      WorkspaceXmlData data) async {
    final context = this.context;
    final configuration = data.configuration;
    var switchTransferOn = false;
    if (configuration != null && !_transferOn()) {
      final choice = await askConfigurationTransfer(context,
          maySwitchOn: ref
              .read(myPermissionsProvider)
              .contains(WorkspacePermission.manageConfiguration));
      if (choice == null || !context.mounted) return null;
      switchTransferOn = choice;
    }
    return (
      apply: configuration != null && (switchTransferOn || _transferOn()),
      switchOn: switchTransferOn,
    );
  }

  /// The preview and its destructive confirm; true when confirmed.
  Future<bool> _confirm(
      WorkspaceXmlData data, ({bool apply, bool switchOn}) choice) async {
    final l10n = context.l10n;
    final counts = workspaceXmlPlanCounts(data);
    final configuration = data.configuration;
    final configurationCount = choice.apply && configuration != null
        ? configurationCounts(configuration)
        : null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(scrollable: true,
          title: Text(l10n.workspaceXmlImportPreviewTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.workspaceXmlImportPreviewCounts(counts.levels,
                        counts.offices, counts.desks, counts.seats),
              ),
              // #180 — own additive line: the four-count key keeps its
              // placeholders untouched across all locales.
              Text(
                l10n.workspaceXmlImportPreviewAccessories(
                        counts.accessories),
              ),
              if (configurationCount != null)
                Text(
                  l10n.workspaceXmlImportPreviewConfiguration(
                          configurationCount.settings,
                          configurationCount.tables,
                          configurationCount.rows),
                ),
              if (configuration != null && !choice.apply)
                Text(l10n
                    .workspaceXmlImportPreviewConfigurationSkipped),
              const SizedBox(height: 12),
              Text(
                l10n.workspaceXmlImportPreviewWarning,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('workspaceXmlImportCancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const Key('workspaceXmlImportConfirm'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                  l10n.workspaceXmlImportConfirm),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  /// #916 — the configuration first: it has no reservation hazard and
  /// must land even when the plan below is refused. True when the plan
  /// was kept because the space has reservations.
  Future<bool> _applyConfigurationAndPlan(
    Workspace workspace,
    WorkspaceXmlData data,
    ({bool apply, bool switchOn}) choice,
    XmlImportProgress progress,
  ) async {
    if (choice.switchOn) {
      await toggleWorkspaceFeature(ref,
          workspace: workspace,
          feature: WorkspaceFeature.configurationTransfer,
          value: true);
    }
    final configuration = data.configuration;
    if (choice.apply && configuration != null) {
      await importWorkspaceConfiguration(ref, workspace.id, configuration);
      progress.anythingApplied = true;
    }
    // The floor plan is the step that can refuse (owner check,
    // reservations). With a configuration already applied the refusal
    // is reported as "plan kept", not as a failure.
    final planKept = await importWorkspaceFloorPlan(ref, workspace.id, data,
        keepOnReservations: choice.apply);
    if (!planKept) progress.anythingApplied = true;
    return planKept;
  }

  /// The outcome on screen: a refused brand colour, then what landed.
  void _announce(WorkspaceXmlData data,
      {required String brandRefused, required bool planKept}) {
    final l10n = context.l10n;
    if (brandRefused.isNotEmpty) {
      AppSnack.error(
        context,
        l10n.brandColorRefused(data.settings.brandColor ?? '', brandRefused),
      );
    }
    if (planKept) {
      AppSnack.info(
        context,
        l10n.workspaceXmlImportConfigurationOnly,
      );
    } else {
      AppSnack.success(
        context,
        l10n.workspaceXmlImportSuccess,
      );
    }
  }

  /// User-facing message for a typed parse failure (#164/#165). The
  /// technical [WorkspaceXmlException.detail] goes to the trace log only.
  String _xmlErrorMessage(AppLocalizations l10n, WorkspaceXmlError error) =>
      switch (error) {
        WorkspaceXmlError.malformed =>
          l10n.workspaceXmlErrorMalformed,
        WorkspaceXmlError.wrongRoot => l10n.workspaceXmlErrorWrongRoot,
        WorkspaceXmlError.unsupportedVersion =>
          l10n.workspaceXmlErrorUnsupportedVersion,
        WorkspaceXmlError.missingElement =>
          l10n.workspaceXmlErrorMissingElement,
        WorkspaceXmlError.missingAttribute =>
          l10n.workspaceXmlErrorMissingAttribute,
        WorkspaceXmlError.invalidValue =>
          l10n.workspaceXmlErrorInvalidValue,
      };
}
