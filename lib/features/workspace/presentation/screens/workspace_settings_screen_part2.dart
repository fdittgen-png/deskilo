// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_settings_screen.dart';

// #2386 — part 2 of _WorkspaceSettingsScreenState, split out of workspace_settings_screen.dart so no
// file holds the whole class.
extension _WorkspaceSettingsScreenStatePart2 on _WorkspaceSettingsScreenState {

  /// Prints the space QR sheet (field request): one card per desk,
  /// office, level and chair, in an A4 grid — saved to Downloads.
  /// #584 — the owner first picks the card size (S/M/L) and which
  /// information rides each card (printed AND embedded in the QR).
  Future<void> _exportSpaceCodes(Workspace workspace) async {
    final l10n = context.l10n;
    final options = await showDialog<SpaceCodesOptions>(
      context: context,
      builder: (_) => const SpaceCodesOptionsDialog(),
    );
    if (options == null || !mounted) return;
    _update(() => _busy = true);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'space codes export failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        // #671 — cover wording and images come from report management.
        final cover = await batchCover(context, ref, docId: 'space_codes', data: {
          'workspace': workspace.name,
          'issued': DateFormat.yMMMMd().format(ref.read(clockProvider).now()),
        });
        if (!mounted || cover == null) return;
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
        if (!mounted || ref.read(currentWorkspaceProvider).value?.id != workspace.id) return;
        if (entries.isEmpty) {
          if (!mounted) return;
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
        if (!mounted) return;
        _announceSaved(l10n, path);
      },
    )) {
      if (mounted) _update(() => _busy = false);
      return;
    }
    if (mounted) _update(() => _busy = false);
  }

  /// Irreversible workspace reset (0039): a destructive dialog that unlocks
  /// its confirm button only once the owner types the exact confirmation
  /// phrase ("I agree"), then wipes all transactions + the floor plan while
  /// keeping settings and members.
  Future<void> _resetWorkspace(Workspace workspace) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ResetConfirmDialog(
        phrase: l10n.workspaceResetConfirmPhrase,
      ),
    );
    if (confirmed != true || !mounted) return;

    _update(() => _busy = true);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace reset failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
          await ref.read(workspaceRepositoryProvider).resetWorkspace(workspace.id);
          // Refresh every surface that read the now-deleted data.
          ref
            ..invalidate(levelsProvider)
            ..invalidate(floorPlanProvider)
            ..invalidate(targetNamesProvider)
            ..invalidate(accessoriesProvider)
            ..invalidate(seatAccessoriesProvider)
            ..invalidate(myWorkspacesProvider);
          invalidateBookingData(ref);
          if (!mounted) return;
          AppSnack.success(
            context,
            l10n.workspaceResetDone,
          );
      },
    )) {
      if (mounted) _update(() => _busy = false);
      return;
    }
    if (mounted) _update(() => _busy = false);
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

  /// Owner-only XML import (#165): pick file → parse (typed errors) →
  /// client-side placement validation → preview + destructive confirm →
  /// transactional replace via the import RPC, settings via the existing
  /// owner writers.
  Future<void> _importXml(Workspace workspace) async {
    final l10n = context.l10n;
    _update(() => _busy = true);
    // #1532 — how far the import got, so a stop partway is not reported
    // as if nothing had happened. Out here because the catch reads it.
    var anythingApplied = false;
    try {
      final pick = ref.read(filePickerProvider);
      final file = await pick(XTypeGroup(
        // Acronym identical in every locale (IBAN precedent, #155); the
        // key exists so the parity gate covers the whole set.
        label: l10n.workspaceXmlFileTypeLabel,
        extensions: const ['xml'],
        mimeTypes: const ['application/xml', 'text/xml'],
      ));
      if (file == null) return; // cancelled
      // Explicit UTF-8 decode: the export declares UTF-8 (#164), and
      // XFile.readAsString is not UTF-8-safe for data-backed files.
      final content = utf8.decode(await file.readAsBytes());
      if (!mounted) return;

      final WorkspaceXmlData data;
      try {
        data = parseWorkspaceXml(content);
      } on WorkspaceXmlException catch (e, st) {
        TraceLogger.instance.error(
            'workspace', 'workspace XML import rejected: ${e.detail}',
            error: e, stackTrace: st);
        if (!mounted) return;
        AppSnack.error(context, _xmlErrorMessage(l10n, e.error));
        return;
      }

      // The editor's placement rules (spec §10) gate the preview: a file
      // whose plan the editor could never have drawn is rejected here.
      final invalid = validateWorkspaceXmlPlan(data);
      if (invalid != null) {
        TraceLogger.instance.error(
            'workspace',
            'workspace XML import plan invalid '
            '(${invalid.problem.name}): ${invalid.detail}');
        if (!mounted) return;
        AppSnack.error(
          context,
          l10n.workspaceXmlErrorInvalidPlan,
        );
        return;
      }

      final counts = workspaceXmlPlanCounts(data);
      // #916 — the configuration section applies when the feature is on;
      // a v1/v2 file has none. #2331 — with the feature off it is no
      // longer skipped in silence: the owner is asked first, and may
      // switch the feature on for this import.
      final configuration = data.configuration;
      var switchTransferOn = false;
      if (configuration != null &&
          !ref
              .read(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.configurationTransfer)) {
        final choice = await askConfigurationTransfer(context,
            maySwitchOn: ref
                .read(myPermissionsProvider)
                .contains(WorkspacePermission.manageConfiguration));
        if (choice == null || !mounted) return;
        switchTransferOn = choice;
      }
      final applyConfiguration = configuration != null &&
          (switchTransferOn ||
              ref
                  .read(enabledFeaturesSyncProvider)
                  .contains(WorkspaceFeature.configurationTransfer));
      final configurationCount =
          applyConfiguration ? configurationCounts(configuration) : null;
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
                if (configuration != null && !applyConfiguration)
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
      if (confirmed != true) return;
      if (!mounted) return;

      final importRepository = ref.read(workspaceImportRepositoryProvider);
      // #916 — the configuration first: it has no reservation hazard and
      // must land even when the plan below is refused.
      if (switchTransferOn) {
        await toggleWorkspaceFeature(ref,
            workspace: workspace,
            feature: WorkspaceFeature.configurationTransfer,
            value: true);
      }
      if (applyConfiguration) {
        await importRepository.importConfiguration(
            workspace.id, configuration);
        anythingApplied = true;
      }
      // The floor plan is the step that can refuse (owner check,
      // reservations). With a configuration already applied the refusal
      // is reported as "plan kept", not as a failure.
      var planKept = false;
      try {
        await importRepository.importFloorPlan(workspace.id, data);
        anythingApplied = true;
      } on PostgrestException catch (e, st) {
        if (!applyConfiguration ||
            !e.message.contains(kWorkspaceHasReservationsError)) {
          rethrow;
        }
        TraceLogger.instance.warn(
            'workspace', 'workspace XML import: plan kept (reservations)',
            error: e, stackTrace: st);
        planKept = true;
      }
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
      anythingApplied = true;
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
      final brandRefused = await applyImportedBrandSeed(
        repository,
        workspace.id,
        data.settings.brandColor,
        check: (argb) =>
            [for (final f in DeskiloTheme.refusals(Color(argb))) f.pair],
      );

      ref
        ..invalidate(myWorkspacesProvider)
        ..invalidate(levelsProvider)
        ..invalidate(floorPlanProvider)
        ..invalidate(targetNamesProvider)
      // #180 — the import may have upserted the catalog and re-created
      // every seat assignment.
        ..invalidate(accessoriesProvider)
        ..invalidate(seatAccessoriesProvider);
      if (applyConfiguration) {
        ref
          ..invalidate(sitesProvider)
          ..invalidate(vatRatesProvider);
      }
      if (!mounted) return;
      // Re-seed the form so the imported settings show immediately.
      _update(() => _seeded = false);
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
    } on PostgrestException catch (e, st) {
      debugPrint('workspace XML import failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'workspace XML import failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        e.message.contains(kWorkspaceHasReservationsError)
            ? (l10n.workspaceXmlImportReservationsError)
            : (l10n.workspaceGenericError),
      );
      if (anythingApplied) _sayPartial(context, l10n);
    } on Object catch (e, st) {
      debugPrint('workspace XML import failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'workspace XML import failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n.workspaceGenericError,
      );
      if (anythingApplied) _sayPartial(context, l10n);
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  /// #763 — a control with no free suffix slot gets the ? at its side.
  Widget _withDot(Widget field, String topic, {required String anchor}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: field),
          HelpDot(topic, anchor: anchor),
        ],
      );
}
