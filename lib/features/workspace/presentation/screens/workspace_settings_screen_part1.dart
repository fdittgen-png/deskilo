// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_settings_screen.dart';

// #2386 — part 1 of _WorkspaceSettingsScreenState, split out of workspace_settings_screen.dart so no
// file holds the whole class.
extension _WorkspaceSettingsScreenStatePart1 on _WorkspaceSettingsScreenState {

  /// Stash the visible template into its language's draft, then show
  /// [lang]'s draft.
  void _switchTemplateLang(String lang) {
    _update(() {
      _templateDrafts[_templateLang] = _invitationTemplate.text;
      _templateLang = lang;
      _invitationTemplate.text = _templateDrafts[lang] ?? '';
    });
  }

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
    _onCountryPicked(code);
  }

  void _onCountryPicked(String? code) {
    if (code == null) return;
    final country = CountryCatalog.byCode(code);
    _update(() {
      _countryCode = code;
      // Re-default both from the catalog (spec §3); the owner can still
      // override the currency before saving.
      _currency.text = country.currencyCode;
      _timezone.text = country.defaultTimezone;
    });
  }

  Future<void> _save(String workspaceId) async {
    if (!WorkspaceFormGroup.validate(_formKey.currentState)) return;
    final code = _countryCode;
    if (code == null) return;
    final l10n = context.l10n;
    _update(() => _busy = true);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'update workspace locale failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
          // #1451 — ONE command, one transaction, against the version the
          // form was opened on. The visible template is stashed first;
          // empty drafts mean "built-in message for that language".
          _templateDrafts[_templateLang] = _invitationTemplate.text;
          try {
            final saved =
                await ref.read(workspaceRepositoryProvider).saveWorkspaceSettings(
                  workspaceId,
                  WorkspaceSettingsSave(
                    expectedModifiedAt: _openedAt,
                    countryCode: code,
                    currencyCode: _currency.text.trim(),
                    timezone: _timezone.text.trim(),
                    whatsappGroup: _whatsappGroup.text.trim(),
                    address: _workspaceAddress.text.trim(),
                    defaultLocale: _defaultLocale,
                    deskOpacity: _deskOpacity,
                    invitationTemplates: Map.of(_templateDrafts),
                    newMemberDefaults: _newMemberDefaults,
                  ),
                );
            // The next Save compares against what was just committed.
            _openedAt = saved.system.modifiedAt;
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
      },
    )) {
      if (mounted) _update(() => _busy = false);
      return;
    }
    if (mounted) _update(() => _busy = false);
  }

  /// Serializes the workspace settings + every level's floor plan + the
  /// accessory catalog and seat assignments (v2, #180) to the versioned
  /// XML format (#164) and hands it to the system share sheet as a `.xml`
  /// file — same seam the bill PDF export uses (#133).
  Future<void> _exportXml(Workspace workspace) async {
    final l10n = context.l10n;
    _update(() => _busy = true);
    // #1012 — every export leaves a trace of its start and its end, so a
    // silent device tells its story; the save is bounded, so a bridge
    // that never answers becomes an error instead of a frozen screen.
    TraceLogger.instance.log(TraceLevel.info, 'workspace',
        'xml export started for ${workspace.id}');
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace XML export failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
          final levels = await ref.read(levelsProvider.future);
          final plans = <({Level level, FloorPlan plan})>[];
          for (final level in levels) {
            plans.add((
              level: level,
              plan: await ref.read(floorPlanProvider(level.id).future),
            ));
          }
          // Inactive entries included — a backup must be complete (#180).
          final accessories =
              await ref.read(accessoriesProvider(includeInactive: true).future);
          final seatAccessories = await ref.read(seatAccessoriesProvider.future);
          // #916 — the configuration section and the plan's references
          // by name, when the feature is on.
          Map<String, Object?>? configuration;
          var siteNames = const <String, String>{};
          var vatRateLabels = const <String, String>{};
          if (ref
              .read(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.configurationTransfer)) {
            configuration = await ref
                .read(workspaceImportRepositoryProvider)
                .exportConfiguration(workspace.id);
            final sites = await ref.read(sitesProvider.future);
            siteNames = {for (final site in sites) site.id: site.name};
            final rates = await ref.read(vatRatesProvider.future);
            vatRateLabels = {for (final rate in rates) rate.id: rate.label};
          }
          final xml = buildWorkspaceXml(
            configuration: configuration,
            siteNames: siteNames,
            vatRateLabels: vatRateLabels,
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
          if (!mounted) return;
          _announceSaved(
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
      },
    )) {
      if (mounted) _update(() => _busy = false);
      return;
    }
    if (mounted) _update(() => _busy = false);
  }

  /// Confirms a local export saved (or reports failure) — never a share.
  void _announceSaved(AppLocalizations l10n, String? path,
      {SnackBarAction? action}) {
    if (path == null) {
      AppSnack.error(context, l10n.commonSaveFailed);
      return;
    }
    AppSnack.success(context, l10n.commonSavedTo(path),
        action: action);
  }

  /// Role label for a member — owner outranks admin outranks member.
  String _granularityLabel(
    AppLocalizations l10n,
    BookingGranularity granularity,
  ) =>
      switch (granularity) {
        BookingGranularity.flexible =>
          l10n.availabilityGranularityFlexible,
        BookingGranularity.halfDay =>
          l10n.availabilityGranularityHalfDay,
        BookingGranularity.fullDay =>
          l10n.availabilityGranularityFullDay,
        BookingGranularity.hours =>
          l10n.availabilityGranularityHours,
        // Minute granularities carry their step in the label itself.
        BookingGranularity.minutes5 ||
        BookingGranularity.minutes15 ||
        BookingGranularity.minutes30 ||
        BookingGranularity.minutes60 =>
          '${granularity.stepMinutes} min',
      };

  /// Renders a complete, human-readable PDF snapshot of the workspace —
  /// settings, every member with their role and status, enabled features,
  /// availability and the whole floor plan — and hands it to the system
  /// share sheet. Unlike the XML export (a machine backup, no members),
  /// this is the owner's shareable configuration record.
  /// #494 — the engine-based workspace report, saved to the device.
  Future<void> _exportWorkspaceReport() async {
    final l10n = context.l10n;
    _update(() => _busy = true);
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace report export failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        await warmLetterDocProviders(ref, 'workspace');
        if (!mounted) return;
        // #496 — the workspace report prints in the workspace's own
        // language chain (no member involved).
        final String language;
        try {
          language = resolveMemberReportLanguage(ref);
        } on AmbiguousReportLanguage {
          AppSnack.error(
            context,
            l10n.reportLanguageAmbiguous,
          );
          return;
        }
        final docL10n = l10nForLanguage(language);
        final data = workspaceReportData(
            reportStringsFor(context, l10n: docL10n, localeName: language),
            workspaceFactsOf(ref, docL10n));
        final report = renderLetterDoc(context, ref,
            docId: 'workspace', data: data, language: language);
        final pdf = await letterDocPdf(context, ref,
            report: report,
            title: docL10n.reportDocWorkspace,
            layoutXml: letterLayoutXml(ref,
                docId: 'workspace', language: language),
            data: data);
        if (!mounted) return;
        final path = await ref.read(fileSaverProvider)(
          bytes: pdf.bytes,
          fileName: pdf.fileName,
        );
        if (!mounted) return;
        _announceSaved(l10n, path);
      },
    );
    if (mounted) _update(() => _busy = false);
  }

  Future<void> _exportConfigPdf(Workspace workspace) async {
    final l10n = context.l10n;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    _update(() => _busy = true);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace config PDF export failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
          final levelsList = await ref.read(levelsProvider.future);
          final plans = <ConfigPdfLevel>[];
          for (final level in levelsList) {
            plans.add((
              level: level,
              plan: await ref.read(floorPlanProvider(level.id).future),
            ));
          }
          final members = await ref.read(workspaceMembersProvider.future);
          final names = await ref.read(memberNamesProvider.future);
          final granularity = await ref.read(bookingGranularityProvider.future);
          final features = await ref.read(enabledFeaturesProvider.future);
          final openWeekdays = await ref.read(openWeekdaysProvider.future);
          final closures = await ref.read(closureDaysProvider.future);

          // ISO weekday (1=Mon..7=Sun) → localized name via a known Monday.
          final weekdayFormat = DateFormat.EEEE(locale);
          String weekdayName(int isoWeekday) =>
              weekdayFormat.format(DateTime(2026, 6, 1 + (isoWeekday - 1)));
          final openDaysLabel = (openWeekdays.toList()..sort())
              .map(weekdayName)
              .join(', ');

          final dateFormat = DateFormat.yMMMd(locale);
          // Formatted once: the l10n branch and its fallback must carry
          // the same stamp.
          final generatedOn =
              dateFormat.format(ref.read(clockProvider).now());
          final closureLabels = [
            for (final closure in closures)
              if (closure.reason.trim().isEmpty) dateFormat.format(closure.day.toLocal()) else '${dateFormat.format(closure.day.toLocal())} — '
                      '${closure.reason}',
          ];

          // Members sorted by name, like the directory.
          final sortedMembers = [...members]..sort(
              (a, b) => (names[a.id] ?? '')
                  .toLowerCase()
                  .compareTo((names[b.id] ?? '').toLowerCase()),
            );
          String memberDetails(Member member) {
            final parts = <String>[
              switch (member.overagePolicy) {
                OveragePolicy.blocked =>
                  l10n.overagePolicyBlocked,
                OveragePolicy.payg =>
                  l10n.overagePolicyPayg,
                OveragePolicy.package =>
                  l10n.overagePolicyPackage,
              },
              if (member.maxActiveReservations != null)
                'max ${member.maxActiveReservations}',
              if (member.canReserveLevel)
                l10n.levelPermissionAllowed,
            ];
            return parts.join(' · ');
          }

          final configMembers = <ConfigPdfMember>[
            for (final member in sortedMembers)
              (
                name: names[member.id] ?? '',
                role: memberRoleLabel(l10n, member),
                status: memberStatusLabel(l10n, member.status),
                details: memberDetails(member),
              ),
          ];

          final strings = workspaceConfigurationStrings(l10n);

          final data = workspaceConfigurationReportData(WorkspaceConfigDocument(strings: strings,
            workspaceName: workspace.name,
            generatedOnLabel: l10n.workspaceConfigPdfGeneratedOn(generatedOn),
            countryLabel: localizedCountryName(l10n, workspace.countryCode),
            currencyCode: workspace.currencyCode,
            timezone: workspace.timezone,
            granularityLabel: _granularityLabel(l10n, granularity),
            members: configMembers,
            featureLabels: [
              // Registry order for a stable list.
              for (final feature in WorkspaceFeature.values)
                if (features.contains(feature)) featureName(l10n, feature),
            ],
            openDaysLabel: openDaysLabel,
            closureLabels: closureLabels,
            levels: plans,
            levelPrices: {
              for (final entry in plans)
                if (entry.level.bookableAsWhole)
                  entry.level.id: entry.level.priceCents == 0
                      ? ''
                      : moneyFormat(workspace.currencyCode, locale: locale).formatMinor(entry.level.priceCents),
            },
            hasCustomInvitationTemplate:
                workspace.invitationTemplate.trim().isNotEmpty));
          await warmLetterDocProviders(ref, 'workspace_configuration');
          if (!mounted || ref.read(currentWorkspaceProvider).value?.id != workspace.id) return;
          final report = renderLetterDoc(context, ref,
              docId: 'workspace_configuration', data: data);
          final pdf = await letterDocPdf(context, ref,
              report: report, title: strings.title, data: data,
              layoutXml: letterLayoutXml(ref, docId: 'workspace_configuration', l10n: l10n));
          if (!mounted) return;
          final path = await ref.read(fileSaverProvider)(
            bytes: pdf.bytes,
            // Slugged (security audit): a raw name may carry path
            // separators — the one export site that skipped the slug.
            fileName: '${safeFileSlug(workspace.name)}-configuration.pdf',
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
}
