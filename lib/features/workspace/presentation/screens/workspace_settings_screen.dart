// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../app/theme.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../directory/presentation/admin_visibility_tile.dart';
import '../../application/apply_brand_seed.dart';
import '../../domain/payment_instructions.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_import.dart';
import '../../domain/workspace_permission.dart';
import '../../domain/workspace_settings_save.dart';
import '../../domain/workspace_xml.dart';
import '../../providers/workspace_providers.dart';
import '../country_change_confirm.dart';
import '../excel_export.dart';
import '../widgets/local_setup_views.dart';
import '../widgets/workspace_form_group.dart';
import '../widgets/workspace_reports.dart';
import 'workspace_settings_backup.dart';
import 'workspace_settings_form.dart';
import 'workspace_settings_host.dart';
import 'workspace_settings_parameters.dart';
import 'workspace_settings_reports.dart';
import 'workspace_settings_restore.dart';

/// Owner-only workspace settings: identity (country/currency/time zone,
/// #153 — a country pick re-defaults both from [CountryCatalog], a
/// manual currency typed afterwards wins), payment instructions, the
/// WhatsApp group link, desk transparency, invitation template, the
/// backup tools (XML export/import, configuration PDF, space-QR PDF)
/// and the guarded workspace reset (0039).
class WorkspaceSettingsScreen extends ConsumerStatefulWidget {
  const WorkspaceSettingsScreen({this.reportsOnly = false, this.reportSection, super.key});
  final bool reportsOnly;

  /// #2313 — the Reporting tab to open (`/reports?section=`).
  final String? reportSection;

  @override
  ConsumerState<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState
    extends ConsumerState<WorkspaceSettingsScreen>
    implements WorkspaceSettingsHost {
  final _formKey = GlobalKey<FormState>();
  final _form = WorkspaceSettingsForm();
  bool _busy = false;

  // #2494 — the tools, each in its own library.
  late final _reports = WorkspaceSettingsReports(this);
  late final _backup = WorkspaceSettingsBackup(this);
  late final _restore = WorkspaceSettingsRestore(this);

  @override
  bool get busy => _busy;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final helpTopic = l10n.helpHintWorkspaceTopic;
    if (widget.reportsOnly) { return Scaffold(
      appBar: AppBar(title: Text(labels.uxReportsTitle)),
      body: workspace == null ? const LoadingView() : WorkspaceReports(
        workspaceName: workspace.name,
        initialSection: widget.reportSection,
        documents: ref.watch(myPermissionsProvider).contains(WorkspacePermission.workspaceSettings)
          ? _toolsTiles(context, l10n: l10n, workspace: workspace, helpTopic: helpTopic, reports: true) : const [])); }
    if (workspace != null) _form.seedOnce(workspace);
    // #1294 — read separately: it lives in billing_rules, not on the
    // workspace row the screen already holds. Seeded once, like the rest —
    // and #1563: until it lands there is nothing to save, so Save omits it.
    _form.seedDefaultsOnce(ref.watch(newMemberDefaultsProvider).value);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workspaceSettingsTitle),
      ),
      body: workspace == null
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: WorkspaceFormSections(children: [
                  // #2313 — tips sit at the top of every screen.
                  const HelpHint(HelpHintId.workspaceSettings),
                  const AdminVisibilityTile(),
                  if(ref.watch(myMemberProvider).value?.actsAsOwner??false)ListTile(key: const ValueKey('workspace-settings-portal-publication'), title:Text(l10n.portalPublication),leading:const Icon(Icons.public),onTap:()=>context.push('/settings/public-page')),
                  ...setupReadinessCards(workspace.id), // #1636 #1656
                  ...WorkspaceParameterTiles(this, _form, _update,
                      helpTopic: helpTopic,
                      onCountryPicked: _confirmCountryPick,
                      onTemplateLang: _switchTemplateLang).tiles(workspace),
                  WorkspaceFormGroup(id: 'tools', title: labels.uxWorkspaceTools, icon: Icons.import_export,
                    children: _toolsTiles(context, l10n: l10n, workspace: workspace, helpTopic: helpTopic)),
                  WorkspaceFormGroup(id: 'danger', title: labels.workspaceDangerZone, icon: Icons.warning_amber, destructive: true,
                    children: _dangerZoneTiles(context, l10n: l10n, workspace: workspace)),
              ]),
            ),
      bottomNavigationBar: workspace == null ? null : WorkspaceSettingsSaveBar(busy: _busy, onSave: () => _save(workspace.id)),
    );
  }

  /// Lets the section libraries rebuild (setState is protected).
  void _update(VoidCallback fn) => setState(fn);

  @override
  Future<void> whileBusy(Future<void> Function() action) async {
    _update(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  @override
  Future<void> runTool(String message, Future<void> Function() action) =>
      whileBusy(() => runGuarded(
            context,
            domain: 'workspace',
            message: message,
            errorText: context.l10n.workspaceGenericError,
            action: action,
          ));

  @override
  void reseed() => _update(_form.reseed);

  List<Widget> _toolsTiles(BuildContext context, {
    required AppLocalizations l10n, required Workspace workspace,
    required String helpTopic, bool reports = false,
  }) => [
                  if (!reports) ...[
                  if (ref
                      .watch(enabledFeaturesSyncProvider)
                      .contains(WorkspaceFeature.workspaceLibrary))
                    ListTile(
                      key: const Key('workspaceSettingsLibrary'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.grid_view_outlined),
                      title: Text(l10n.libraryTitle),
                      subtitle: Text(l10n.librarySave),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/library'),
                    ),
                  // #164 — versioned XML snapshot of settings + floor
                  // plan; the whole screen is owner-only already.
                  ListTile(
                    key: const Key('workspaceSettingsExportXml'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_file_outlined),
                    title: HelpDotTitle(
                      l10n.workspaceXmlExport,
                      helpTopic,
                      anchor: HelpAnchor.exportSpaceXml,
                    ),
                    subtitle: Text(
                      l10n.workspaceXmlExportSubtitle,
                    ),
                    enabled: !_busy,
                    onTap: () => _backup.exportXml(workspace),
                  ),
                  ],
                  if (reports) ...[
                  // Human-readable PDF snapshot — settings + every member +
                  // the whole floor plan. Owner-only like the rest.
                  ListTile(
                    key: const Key('workspaceSettingsExportPdf'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: HelpDotTitle(
                      l10n.workspaceConfigPdfExport,
                      helpTopic,
                      anchor: HelpAnchor.exportConfigPdf,
                    ),
                    subtitle: Text(
                      l10n.workspaceConfigPdfExportSubtitle,
                    ),
                    enabled: !_busy,
                    onTap: () => _reports.exportConfigPdf(workspace),
                  ),
                  // #494 — the workspace report through the REPORT
                  // engine: templated, translated, image-capable.
                  ListTile(
                    key: const Key('workspaceSettingsWorkspaceReport'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.summarize_outlined),
                    title: HelpDotTitle(
                      l10n.reportDocWorkspace,
                      helpTopic,
                      anchor: HelpAnchor.exportWorkspaceReport,
                    ),
                    subtitle: Text(l10n.reportDocWorkspaceSubtitle),
                    onTap: _exportWorkspaceReport,
                  ),
                  // Space QR codes (field request): one printable card
                  // per desk, office and level — members scan them to
                  // reserve or check in on the spot.
                  if (ref
                      .watch(enabledFeaturesSyncProvider)
                      .contains(WorkspaceFeature.spaceQrCodes))
                  ListTile(
                    key: const Key('workspaceSettingsSpaceCodes'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.qr_code_2_outlined),
                    title: HelpDotTitle(
                      l10n.spaceCodesTitle,
                      helpTopic,
                      anchor: HelpAnchor.exportSpaceQr,
                    ),
                    subtitle: Text(
                      l10n.spaceCodesDesc,
                    ),
                    enabled: !_busy,
                    onTap: () => _backup.exportSpaceCodes(workspace),
                  ),
                  // #395 — the full data workbook. The tile is the ONLY
                  // surface, so the flag gate lives here (no route to
                  // guard); headers inside the file are stable English
                  // like the XML schema, the UI around it is localized.
                  // #1310 S0 — and the permission the roles screen
                  // promises: exportData is what governs BULK export.
                  if (ref
                          .watch(enabledFeaturesSyncProvider)
                          .contains(WorkspaceFeature.dataExport) &&
                      ref
                          .watch(myPermissionsProvider)
                          .contains(WorkspacePermission.exportData))
                  ListTile(
                    key: const Key('workspaceSettingsExportExcel'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.table_view_outlined),
                    title: HelpDotTitle(
                      l10n.workspaceExcelExport,
                      helpTopic,
                      anchor: HelpAnchor.exportExcel,
                    ),
                    subtitle: Text(
                      l10n.workspaceExcelExportSubtitle,
                    ),
                    enabled: !_busy,
                    onTap: () => whileBusy(
                        () => exportWorkspaceExcel(context, ref, workspace)),
                  ),
                  ..._reports.dataReportTiles(l10n, workspace),
                  ],
                  if (!reports)
                  // #165 — restore from an exported file. Replaces the
                  // floor plan (guarded by preview + destructive confirm);
                  // the whole screen is owner-only already.
                  ListTile(
                    key: const Key('workspaceSettingsImportXml'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_open_outlined),
                    title: HelpDotTitle(
                      l10n.workspaceXmlImport,
                      helpTopic,
                      anchor: HelpAnchor.exportSpaceImport,
                    ),
                    subtitle: Text(
                      l10n.workspaceXmlImportSubtitle,
                    ),
                    enabled: !_busy,
                    onTap: () => _importXml(workspace),
                  ),
                  const SizedBox(height: 24),

      ];

  List<Widget> _dangerZoneTiles(BuildContext context, {
    required AppLocalizations l10n, required Workspace workspace,
  }) => [
                  ListTile(
                    key: const Key('workspaceSettingsReset'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      l10n.workspaceResetTitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    subtitle: Text(
                      l10n.workspaceResetSubtitle,
                    ),
                    enabled: !_busy,
                    onTap: () => _restore.resetWorkspace(workspace),
                  ),
      ];

  /// #494 — the engine-based workspace report, saved to the device.
  Future<void> _exportWorkspaceReport() => _reports.exportWorkspaceReport();

  /// Stash the visible template into its language's draft, then show
  /// [lang]'s draft.
  void _switchTemplateLang(String lang) =>
      _update(() => _form.switchTemplateLang(lang));

  /// #2454 — a country that does not offer a feature that is on names what
  /// would switch off, and asks first (the stored switches are kept).
  Future<void> _confirmCountryPick(String? code) async {
    if (code == null) return;
    final lost = featuresLostInCountry(
      ref.read(enabledFeaturesSyncProvider),
      code,
    );
    if (lost.isNotEmpty && !await confirmCountryChange(context, code, lost)) {
      return;
    }
    _update(() => _form.pickCountry(code));
  }

  Future<void> _save(String workspaceId) async {
    if (!WorkspaceFormGroup.validate(_formKey.currentState)) return;
    final code = _form.countryCode;
    if (code == null) return;
    final l10n = context.l10n;
    await runTool('update workspace locale failed', () async {
          // #1451 — ONE command, one transaction, against the version the
          // form was opened on.
          try {
            final saved =
                await ref.read(workspaceRepositoryProvider).saveWorkspaceSettings(
                  workspaceId,
                  _form.toSave(code),
                );
            // The next Save compares against what was just committed.
            _form.openedAt = saved.system.modifiedAt;
          } on WorkspaceSettingsConflict {
            // Nothing was written; everything typed stays on screen.
            if (mounted) {
              AppSnack.error(
                context,
                l10n.workspaceSettingsConflict,
              );
            }
            return;
          }
          ref
            ..invalidate(newMemberDefaultsProvider)
          // Every money surface watches the workspace chain — invalidating it
          // re-renders all amounts in the new currency immediately.
            ..invalidate(myWorkspacesProvider);
          if (!mounted) return;
          AppSnack.success(
            context,
            l10n.workspaceSettingsSaved,
          );
    });
  }

  /// Owner-only XML import (#165); the steps are [WorkspaceSettingsRestore]'s,
  /// a failure is told here.
  Future<void> _importXml(Workspace workspace) async {
    // #1532 — how far the import got, so a stop partway is not reported
    // as if nothing had happened.
    final progress = XmlImportProgress();
    await whileBusy(() async {
      try {
        await _restore.importXml(workspace, progress);
      } on Object catch (e, st) {
        debugPrint('workspace XML import failed: $e\n$st');
        TraceLogger.instance.error('workspace', 'workspace XML import failed',
            error: e, stackTrace: st);
        if (!mounted) return;
        final l10n = context.l10n;
        AppSnack.error(
          context,
          e is PostgrestException &&
                  e.message.contains(kWorkspaceHasReservationsError)
              ? (l10n.workspaceXmlImportReservationsError)
              : (l10n.workspaceGenericError),
        );
        if (progress.anythingApplied) _sayPartial(context, l10n);
      }
    });
  }

  @override
  Future<String> applyImportedSettings(
    Workspace workspace,
    WorkspaceXmlData data,
    XmlImportProgress progress, {
    required bool switchTransferOn,
  }) async {
    // Settings ride the EXISTING owner writers (#153/#155/#146). The
    // workspace NAME has no update path yet and is deliberately skipped.
    final repository = ref.read(workspaceRepositoryProvider);
    await repository.updateWorkspaceLocale(
      workspace.id,
      countryCode: data.settings.countryCode,
      currencyCode: data.settings.currencyCode,
      timezone: data.settings.timezone,
    );
    await repository.setPaymentInstructions(
      workspace.id,
      PaymentInstructions.fromDb(data.settings.paymentInstructions),
    );
    progress.anythingApplied = true;
    // #2331 — the file's own flags must not switch back off what the
    // owner just switched on for this import.
    await repository.setFeatureFlags(workspace.id, {
      ...data.settings.featureFlags,
      if (switchTransferOn)
        for (final e in featureFlagsToggleDelta(
                feature: WorkspaceFeature.configurationTransfer, value: true)
            .entries)
          e.key.dbKey: e.value,
    });
    // #1289 — a brand seed the document carries is measured before it
    // is written; refused, the rest of the import still applies.
    return applyImportedBrandSeed(
      repository,
      workspace.id,
      data.settings.brandColor,
      check: (argb) =>
          [for (final f in DeskiloTheme.refusals(Color(argb))) f.pair],
    );
  }
}


/// #1532 — the import applies several things in sequence, and its
/// partial steps are deliberate (#916, #1289). What was missing is that
/// nobody said so: a floor plan already replaced is not nothing, and
/// being told only that the import failed leaves the owner to find out.
void _sayPartial(BuildContext context, AppLocalizations l10n) =>
    AppSnack.info(
      context,
      l10n.workspaceXmlImportPartial,
    );
