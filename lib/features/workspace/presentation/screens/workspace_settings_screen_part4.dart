// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_settings_screen.dart';

// #2386 — part 4 of _WorkspaceSettingsScreenState, split out of workspace_settings_screen.dart so no
// file holds the whole class.
extension _WorkspaceSettingsScreenStatePart4 on _WorkspaceSettingsScreenState {

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
                    onTap: () => _exportXml(workspace),
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
                    onTap: () => _exportConfigPdf(workspace),
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
                    onTap: () => _exportSpaceCodes(workspace),
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
                    onTap: () async {
                      _update(() => _busy = true);
                      await exportWorkspaceExcel(context, ref, workspace);
                      if (mounted) _update(() => _busy = false);
                    },
                  ),
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
                    onTap: () => _resetWorkspace(workspace),
                  ),
      ];
}
