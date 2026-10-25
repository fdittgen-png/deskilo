// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/country_names.dart';
import '../../../../core/i18n/workspace_locale_fields.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/settings.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/presentation/widgets/billing_rules_dialog.dart';
import '../../../money/presentation/widgets/dunning_rules_dialog.dart';
import '../../domain/invitation_message.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/new_member_defaults_tiles.dart';
import '../widgets/settings_editor.dart';
import '../widgets/workspace_form_group.dart';
import '../widgets/workspace_own_screens.dart';
import 'workspace_settings_form.dart';
import 'workspace_settings_host.dart';

/// #1154 / #2494 — the workspace's identity and parameters — name,
/// country, currency, zone, hours, policies, invitation: the first slice
/// of the settings form, one group per method. Everything typed rides
/// the screen's Save button through [form].
class WorkspaceParameterTiles {
  WorkspaceParameterTiles(
    this.host,
    this.form,
    this._update, {
    required this.helpTopic,
    required this.onCountryPicked,
    required this.onTemplateLang,
  });

  final WorkspaceSettingsHost host;
  final WorkspaceSettingsForm form;

  /// The screen's setState: an edit here rebuilds the form.
  final void Function(VoidCallback fn) _update;
  final String helpTopic;

  /// #2454 — a picked country is confirmed by the screen first.
  final ValueChanged<String?> onCountryPicked;

  /// Pages the invitation draft to another language.
  final ValueChanged<String> onTemplateLang;

  BuildContext get context => host.context;
  WidgetRef get ref => host.ref;
  bool get busy => host.busy;

  /// The tiles, in the order the form shows them.
  List<Widget> tiles(Workspace workspace) {
    final l10n = context.l10n;
    return [
                  Text(
                    workspace.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _general(l10n),
                  _payments(l10n),
                  _community(l10n),
                  _appearance(l10n),
                  _membership(l10n),
    ];
  }

  /// The identity basics: country, currency and zone, language, address.
  Widget _general(AppLocalizations l10n) =>
                  WorkspaceFormGroup(id: 'general', title: l10n.uxWorkspaceGeneral, icon: Icons.location_on_outlined, initiallyExpanded: true, children: [
                  _withDot(
                    DropdownButtonFormField<String>(
                      key: const Key('workspaceSettingsCountry'),
                      isExpanded: true,
                      initialValue: form.countryCode,
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
                      onChanged: busy ? null : onCountryPicked,
                    ),
                    helpTopic,
                    anchor: HelpAnchor.workspaceCountry,
                  ),
                  const SizedBox(height: 12),
                  // #711 — currency picker and time-zone search, in
                  // core/i18n so the onboarding form can reuse them.
                  _withDot(
                    WorkspaceLocaleFields(
                      currency: form.currency,
                      timezone: form.timezone,
                      enabled: !busy,
                      onTimezonePicked: (zone) =>
                          _update(() => form.timezone.text = zone),
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
                      initialValue: form.defaultLocale,
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
                        for (final entry in WorkspaceSettingsForm.languages.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => _update(
                              () => form.defaultLocale = value ?? ''),
                    ),
                    helpTopic,
                    anchor: HelpAnchor.workspaceLanguage,
                  ),
                  const SizedBox(height: 12),
                  // 0060 — the postal address printed as the invoice
                  // letterhead. Lives with the other identity basics.
                  TextFormField(
                    key: const Key('workspaceSettingsAddress'),
                    controller: form.workspaceAddress,
                    enabled: !busy,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.workspaceAddressLabel,
                      suffixIcon: HelpDot(helpTopic,
                        anchor: HelpAnchor.workspaceAddress,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ]);

  /// Payments and billing: methods, legal identity, reports and the billing tools.
  Widget _payments(AppLocalizations l10n) =>
                  WorkspaceFormGroup(id: 'payments', title: l10n.workspacePaymentsBillingTitle, icon: Icons.account_balance_wallet_outlined, children: [
                  if (ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.moneyTab))
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
                  ..._billingTools(l10n),
                  const SizedBox(height: 24),
                  ]);

  /// The community: the WhatsApp group and the invitation message.
  Widget _community(AppLocalizations l10n) =>
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
                    controller: form.whatsappGroup,
                    enabled: !busy,
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
                      for (final entry in WorkspaceSettingsForm.languages.entries)
                        ChoiceChip(
                          key: ValueKey(
                              'workspace-invitation-lang-${entry.key}'),
                          label: Text(entry.value),
                          selected: form.templateLang == entry.key,
                          onSelected: busy
                              ? null
                              : (_) => onTemplateLang(entry.key),
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
                          onPressed: busy
                              ? null
                              : () {
                                  final t = form.invitationTemplate;
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
                    controller: form.invitationTemplate,
                    enabled: !busy,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: invitationTemplateMaxLength,
                    decoration: InputDecoration(
                      labelText: l10n.invitationTemplateTitle,
                      hintText: l10n.invitationTemplateHint,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ]);

  /// Appearance: the rows with a screen of their own, and desk transparency.
  Widget _appearance(AppLocalizations l10n) =>
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
                    value: form.deskOpacity.toDouble(),
                    label: l10n.workspaceDeskOpacityValue(form.deskOpacity),
                    onChanged: busy
                        ? null
                        : (v) => _update(() => form.deskOpacity = v.round()),
                  ),
                  Text(
                    l10n.workspaceDeskOpacityValue(form.deskOpacity),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  ]);

  /// What a newly joining member starts with (#1294).
  Widget _membership(AppLocalizations l10n) =>
                  WorkspaceFormGroup(id: 'membership', title: l10n.newMemberDefaultsTitle, icon: Icons.person_add_outlined, children: [
                  NewMemberDefaultsTiles(
                    defaults: form.newMemberDefaults,
                    enabled: !busy,
                    failed: ref.watch(newMemberDefaultsProvider).hasError,
                    onRetry: () => ref.invalidate(newMemberDefaultsProvider),
                    onSubscriptionChanged: (pct) => _update(() =>
                        form.newMemberDefaults = form.newMemberDefaults?.copyWith(subscriptionPct: pct)),
                    onOveragePolicyChanged: (policy) => _update(() =>
                        form.newMemberDefaults = form.newMemberDefaults?.copyWith(overagePolicy: policy)),
                  ),
                  const SizedBox(height: 24),
                  ]);

  /// The billing tools beside the payment rows.
  List<Widget> _billingTools(AppLocalizations l10n) => [
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

  /// #763 — a control with no free suffix slot gets the ? at its side.
  Widget _withDot(Widget field, String topic, {required String anchor}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: field),
          HelpDot(topic, anchor: anchor),
        ],
      );
}
