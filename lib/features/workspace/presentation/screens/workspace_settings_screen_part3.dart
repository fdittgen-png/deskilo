// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_settings_screen.dart';

// #2386 — part 3 of _WorkspaceSettingsScreenState, split out of workspace_settings_screen.dart so no
// file holds the whole class.
extension _WorkspaceSettingsScreenStatePart3 on _WorkspaceSettingsScreenState {

  /// #1154 — the workspace's identity and parameters — name, country, currency, zone, hours, policies, invitation. One of the three slices of a this.build() that was 577
  /// lines long; the tiles are unchanged, only the list is cut.
  List<Widget> _parametersTiles(
    BuildContext context, {
    required AppLocalizations l10n,
    required Workspace workspace,
    required String helpTopic,
  }) =>
      [
                  Text(
                    workspace.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  WorkspaceFormGroup(id: 'general', title: l10n.uxWorkspaceGeneral, icon: Icons.location_on_outlined, initiallyExpanded: true, children: [
                  _withDot(
                    DropdownButtonFormField<String>(
                      key: const Key('workspaceSettingsCountry'),
                      isExpanded: true,
                      initialValue: _countryCode,
                      decoration: InputDecoration(
                        labelText: l10n.workspaceCountryLabel,
                      ),
                      items: [
                        for (final country in CountryCatalog.countries)
                          DropdownMenuItem(
                            value: country.code,
                            child: Text(
                                localizedCountryName(l10n, country.code)),
                          ),
                      ],
                      onChanged: _busy ? null : _confirmCountryPick,
                    ),
                    helpTopic,
                    anchor: HelpAnchor.workspaceCountry,
                  ),
                  const SizedBox(height: 12),
                  // #711 — currency picker and time-zone search, in
                  // core/i18n so the onboarding form can reuse them.
                  _withDot(
                    WorkspaceLocaleFields(
                      currency: _currency,
                      timezone: _timezone,
                      enabled: !_busy,
                      onTimezonePicked: (zone) =>
                          _update(() => _timezone.text = zone),
                    ),
                    helpTopic,
                    anchor: HelpAnchor.workspaceCurrencyTimezone,
                  ),
                  const SizedBox(height: 12),
                  // #486 — the workspace's own language: invitations
                  // default to it.
                  _withDot(
                    DropdownButtonFormField<String>(
                      key: const Key('workspaceSettingsLanguage'),
                      isExpanded: true,
                      initialValue: _defaultLocale,
                      decoration: InputDecoration(
                        labelText: l10n.workspaceLanguageLabel,
                        helperMaxLines: 3,
                        helperText: l10n.workspaceLanguageHelper,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(l10n.workspaceLanguageUnset),
                        ),
                        for (final entry in _WorkspaceSettingsScreenState._languages.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => _update(
                              () => _defaultLocale = value ?? ''),
                    ),
                    helpTopic,
                    anchor: HelpAnchor.workspaceLanguage,
                  ),
                  const SizedBox(height: 12),
                  // 0060 — the postal address printed as the invoice
                  // letterhead. Lives with the other identity basics.
                  TextFormField(
                    key: const Key('workspaceSettingsAddress'),
                    controller: _workspaceAddress,
                    enabled: !_busy,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.workspaceAddressLabel,
                      suffixIcon: HelpDot(helpTopic,
                        anchor: HelpAnchor.workspaceAddress,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ]),
                  WorkspaceFormGroup(id: 'payments', title: l10n.workspacePaymentsBillingTitle, icon: Icons.account_balance_wallet_outlined, children: [
                  ListTile(
                    key: const Key('workspaceSettingsPaymentMethods'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                        Icons.account_balance_wallet_outlined),
                    title: Text(l10n.paymentInstructionsTitle),
                    subtitle: Text(l10n.paymentMethodsSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/payment-methods'),
                  ),
                  // 0069 — the legal identity the e-invoice needs lives
                  // on its own screen: the regime decides which fields
                  // even apply.
                  ListTile(
                    key: const Key('workspaceSettingsLegalIdentity'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(l10n.legalIdentityTitle),
                    subtitle: Text(l10n.legalIdentitySubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/legal-identity'),
                  ),
                  ..._billingTools(context, l10n: l10n, helpTopic: helpTopic),
                  const SizedBox(height: 24),
                  ]),
                  WorkspaceFormGroup(id: 'community', title: l10n.uxWorkspaceCommunity, icon: Icons.forum_outlined, children: [
                  // #231 — the community's WhatsApp group; the link is
                  // shown to members in the directory (#232).
                  Text(
                    l10n.workspaceWhatsappGroupTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.workspaceWhatsappGroupHelper,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsWhatsappGroup'),
                    controller: _whatsappGroup,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l10n.workspaceWhatsappGroupLabel,
                      suffixIcon: HelpDot(helpTopic,
                        anchor: HelpAnchor.workspaceWhatsappGroup,
                      ),
                    ),
                    // Same prefix check as the 0029 column constraint
                    // (WhatsappGroupRules cross-pins both); empty is
                    // valid and clears the link.
                    validator: (value) =>
                        WhatsappGroupRules.isValid(value?.trim() ?? '')
                            ? null
                            : (l10n.workspaceWhatsappGroupInvalid),
                  ),
                  const SizedBox(height: 24),
                  // 0049 — the invitation message template. Tags are
                  // listed as selectable chips; empty uses the localized
                  // built-in message (invite sheet on the ID & QR screen).
                  Row(children: [
                    Expanded(child: Text(
                      l10n.invitationTemplateTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    )),
                    HelpDot(helpTopic,
                      anchor: HelpAnchor.workspaceInvitationMessage,
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    l10n.invitationTemplateHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  // #486 — one template per language: the chips page
                  // through the drafts, empty = built-in message.
                  //
                  // #1269 — the row carried no label, so a row of
                  // English / Français / Deutsch chips at the top of a
                  // settings form read as "the language". It is not:
                  // it says which draft you are editing, it is re-derived
                  // from the workspace language on every open, and
                  // nothing about it is saved. Say so.
                  Text(
                    l10n.invitationTemplateLanguage,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final entry in _WorkspaceSettingsScreenState._languages.entries)
                        ChoiceChip(
                          key: ValueKey(
                              'workspace-invitation-lang-${entry.key}'),
                          label: Text(entry.value),
                          selected: _templateLang == entry.key,
                          onSelected: _busy
                              ? null
                              : (_) => _switchTemplateLang(entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in InvitationTags.all)
                        ActionChip(
                          key: ValueKey('invitation-tag-$tag'),
                          label: Text(tag),
                          onPressed: _busy
                              ? null
                              : () {
                                  final t = _invitationTemplate;
                                  final sel = t.selection.isValid
                                      ? t.selection.start
                                      : t.text.length;
                                  t.text = t.text.substring(0, sel) +
                                      tag +
                                      t.text.substring(sel);
                                  t.selection = TextSelection.collapsed(
                                    offset: sel + tag.length,
                                  );
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsInvitationTemplate'),
                    controller: _invitationTemplate,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: invitationTemplateMaxLength,
                    decoration: InputDecoration(
                      labelText: l10n.invitationTemplateTitle,
                      hintText: l10n.invitationTemplateHint,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ]),
                  WorkspaceFormGroup(id: 'appearance', title: l10n.uxWorkspaceAppearance, icon: Icons.palette_outlined, children: [
                  // #1277 / #1289 — the rows that open a screen of their
                  // own: neither rides the Save button below.
                  WorkspaceOwnScreens(helpTopic: helpTopic),
                  const SizedBox(height: 24),
                  // 0040 — desk transparency. Rides the same Save button.
                  Row(children: [
                    Expanded(child: Text(
                      l10n.workspaceDeskTransparencyTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    )),
                    HelpDot(helpTopic,
                      anchor: HelpAnchor.workspaceDeskTransparency,
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    l10n.workspaceDeskTransparencyHelper,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    key: const Key('workspaceSettingsDeskOpacity'),
                    min: 20,
                    max: 100,
                    divisions: 16,
                    value: _deskOpacity.toDouble(),
                    label: l10n.workspaceDeskOpacityValue(_deskOpacity),
                    onChanged: _busy
                        ? null
                        : (v) => _update(() => _deskOpacity = v.round()),
                  ),
                  Text(
                    l10n.workspaceDeskOpacityValue(_deskOpacity),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  ]),
                  WorkspaceFormGroup(id: 'membership', title: l10n.newMemberDefaultsTitle, icon: Icons.person_add_outlined, children: [
                  NewMemberDefaultsTiles(
                    defaults: _newMemberDefaults,
                    enabled: !_busy,
                    failed: ref.watch(newMemberDefaultsProvider).hasError,
                    onRetry: () => ref.invalidate(newMemberDefaultsProvider),
                    onSubscriptionChanged: (pct) => _update(() =>
                        _newMemberDefaults = _newMemberDefaults?.copyWith(subscriptionPct: pct)),
                    onOveragePolicyChanged: (policy) => _update(() =>
                        _newMemberDefaults = _newMemberDefaults?.copyWith(overagePolicy: policy)),
                  ),
                  const SizedBox(height: 24),
                  ]),

      ];

  List<Widget> _billingTools(BuildContext context, {
    required AppLocalizations l10n, required String helpTopic,
  }) => [
                  ListTile(key: const Key('workspaceSettingsReports'),
                    leading: const Icon(Icons.summarize_outlined),
                    title: Text(l10n.uxReportsTitle),
                    subtitle: Text(l10n.uxReportsHint),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/reports')),
                  if (ref
                      .watch(enabledFeaturesSyncProvider)
                      .contains(WorkspaceFeature.invoicing))
                  ListTile(
                    key: const Key('workspaceSettingsDunning'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.rule_outlined),
                    title: HelpDotTitle(
                      l10n.dunningSettingsTitle,
                      helpTopic,
                      anchor: HelpAnchor.remindersRules,
                    ),
                    subtitle: Text(
                      l10n.dunningLevels,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => showDunningRulesDialog(context, ref),
                  ),
                  // #2484 — the registry of business values, edited here.
                  if (ref
                      .watch(enabledFeaturesSyncProvider)
                      .contains(WorkspaceFeature.configurableSettings))
                    ListTile(
                      key: const Key('workspaceSettingsConfigurable'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.tune_outlined),
                      title: Text(l10n.settingsWorkspaceTitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showSettingsEditorSheet(
                        context,
                        title: l10n.settingsWorkspaceTitle,
                        scope: SettingScope.workspace,
                        workspaceId: ref.read(currentWorkspaceProvider).value?.id,
                        canEdit: true,
                      ),
                    ),
                  // #802 — WHEN the two automatic invoice runs happen.
                  // Beside the reminder rules on purpose: issuing and
                  // chasing are the same conversation with a member.
                  if (ref.watch(enabledFeaturesSyncProvider).any((f) =>
                      f == WorkspaceFeature.subscriptionInvoices ||
                      f == WorkspaceFeature.usageInvoices))
                    ListTile(
                      key: const Key('workspaceSettingsBillingRules'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_repeat_outlined),
                      title: HelpDotTitle(
                        l10n.billingRulesTitle,
                        l10n.billingRulesTitle,
                        anchor: HelpAnchor.billingSchedule,
                      ),
                      subtitle: Text(
                        l10n.billingRulesSubtitle,
                      ),
                      onTap: () => showBillingRulesDialog(context, ref),
                    ),
      ];

  /// #2862 — the same rows as the workbook, as a readable report, under
  /// the export it reads and the same permission.
  List<Widget> _dataReportTiles(AppLocalizations l10n, Workspace workspace) => [
        if (ref
                .watch(enabledFeaturesSyncProvider)
                .contains(WorkspaceFeature.dataReport) &&
            ref
                .watch(myPermissionsProvider)
                .contains(WorkspacePermission.exportData))
          ListTile(
            key: const Key('workspaceSettingsDataReport'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(l10n.featureDataReportTitle),
            subtitle: Text(l10n.dataReportSubtitle),
            enabled: !_busy,
            onTap: () => _exportDataReport(workspace),
          ),
      ];

  /// The workspace data report: the workbook's rows as a readable PDF,
  /// with the plan of each level drawn as the app draws it.
  Future<void> _exportDataReport(Workspace workspace) async {
    final l10n = context.l10n;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final watermark = developmentMark(context, ref);
    await _whileBusy(() => runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace data report failed',
      errorText: l10n.dataReportFailed,
      action: () async {
        final details = await _dataReportDetails(workspace);
        final buying = await readDataReportPurchasing(ref, workspace.id);
        final report = buildWorkspaceDataReport(details,
            purchases: buying.purchases, suppliers: buying.suppliers);
        final colors = DeskiloTheme.light().colorScheme;
        final images = {
          for (final entry in details.plansByLevel.entries)
            entry.key: ?await buildPlanPng(entry.value, colors: colors),
        };
        final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        final pdf = await buildWorkspaceDataReportPdf(
          WorkspaceDataReportPdfRequest(
            report: report,
            strings: workspaceDataReportStrings(l10n,
                currency: workspace.currencyCode, locale: locale),
            generatedAt: WorkspaceTime.wall(ref.read(clockProvider).now()),
            baseFont: pw.Font.ttf(regular),
            boldFont: pw.Font.ttf(bold),
            planImages: images,
            watermark: watermark,
          ),
        );
        if (!mounted) return;
        final path = await ref.read(fileSaverProvider)(
          bytes: pdf,
          fileName: '${safeFileSlug(workspace.name)}-data-report.pdf',
        );
        if (!mounted) return;
        _announceSaved(l10n, path);
      },
    ));
  }

  /// Runs [action] with the screen's tools disabled until it ends.
  Future<void> _whileBusy(Future<void> Function() action) async {
    _update(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  /// The rows the workbook's sheets are written from.
  Future<WorkspaceExportDetails> _dataReportDetails(Workspace workspace) async {
    final levels = await ref.read(levelsProvider.future);
    final invoices = ref.read(invoiceQueriesProvider);
    return WorkspaceExportDetails(
      workspace: workspace,
      levels: levels,
      plansByLevel: {
        for (final level in levels)
          level.id: await ref.read(floorPlanProvider(level.id).future),
      },
      memberName: await ref.read(memberNamesProvider.future),
      ledger: await ref
          .read(memberAccountQueriesProvider)
          .fetchWorkspaceLedger(workspace.id),
      events: const [],
      decisions: const {},
      invoices: await invoices.fetchInvoices(workspace.id),
      members: await ref.read(workspaceMembersProvider.future),
      reservations: await ref
          .read(reservationRepositoryProvider)
          .fetchAllForExport(workspace.id),
      invoiceMatches: await invoices.fetchInvoiceMatches(workspace.id),
    );
  }
}
