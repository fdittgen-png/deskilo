// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';

import '../../../../core/country/country_catalog.dart';
import '../../domain/invitation_message.dart';
import '../../domain/new_member_defaults.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_settings_save.dart';

/// #2494 — what the owner types on the settings screen before Save:
/// identity (country/currency/time zone, #153), the WhatsApp group link
/// (#231), the address, the invitation drafts per language (#486), desk
/// transparency (0040) and the new-member defaults (#1294). The State
/// owns one and rebuilds around its changes.
class WorkspaceSettingsForm {
  final currency = TextEditingController();
  final timezone = TextEditingController();
  // #231 — the community's WhatsApp group invite link (directory, #232).
  final whatsappGroup = TextEditingController();
  final workspaceAddress = TextEditingController();
  final invitationTemplate = TextEditingController();
  // 0040 — desk fill opacity percentage (20..100); rides the Save button.
  int deskOpacity = 100;
  // #1294 — what a newly joining member starts with; rides the Save too.
  // #1563 — null until the separate read lands: never send a fallback.
  NewMemberDefaults? newMemberDefaults;
  String? countryCode;
  // #486 — the workspace's own language ('' = sender's app language)
  // and the per-language invitation drafts the chips page through.
  String defaultLocale = '';
  String templateLang = 'en';
  final Map<String, String> templateDrafts = {};

  static const Map<String, String> languages = {
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'it': 'Italiano',
  };

  /// Seed the form ONCE from the loaded workspace; later rebuilds must
  /// not clobber the owner's in-progress edits.
  bool _seeded = false;

  /// #1451 — the workspace row's version when the form was filled.
  DateTime? openedAt;
  bool _seededDefaults = false;

  /// Fills the form from [workspace] the first time it arrives.
  void seedOnce(Workspace workspace) {
    if (_seeded) return;
    _seeded = true;
    countryCode = workspace.countryCode;
    currency.text = workspace.currencyCode;
    timezone.text = workspace.timezone;
    // #486 — one draft per language (invitationDraftsOf).
    templateDrafts.addAll(invitationDraftsOf(
      workspace.invitationTemplates,
      legacy: workspace.invitationTemplate,
      languages: languages.keys,
    ));
    defaultLocale = workspace.defaultLocale;
    templateLang = languages.containsKey(defaultLocale) ? defaultLocale : 'en';
    whatsappGroup.text = workspace.whatsappGroup;
    workspaceAddress.text = workspace.address;
    invitationTemplate.text = templateDrafts[templateLang] ?? '';
    deskOpacity = workspace.deskOpacity;
    openedAt = workspace.system.modifiedAt;
  }

  /// #1294 / #1563 — the defaults live in billing_rules, read separately;
  /// seeded once, like the rest.
  void seedDefaultsOnce(NewMemberDefaults? loaded) {
    if (loaded == null || _seededDefaults) return;
    _seededDefaults = true;
    newMemberDefaults = loaded;
  }

  /// The next build fills the form again (after an import).
  void reseed() => _seeded = false;

  /// Stash the visible template into its language's draft, then show
  /// [lang]'s draft.
  void switchTemplateLang(String lang) {
    templateDrafts[templateLang] = invitationTemplate.text;
    templateLang = lang;
    invitationTemplate.text = templateDrafts[lang] ?? '';
  }

  /// Re-default currency and zone from the catalog (spec §3); the owner
  /// can still override the currency before saving.
  void pickCountry(String code) {
    final country = CountryCatalog.byCode(code);
    countryCode = code;
    currency.text = country.currencyCode;
    timezone.text = country.defaultTimezone;
  }

  /// #1451 — the one save command, against the version the form was
  /// opened on. The visible template is stashed first; empty drafts mean
  /// "built-in message for that language".
  WorkspaceSettingsSave toSave(String code) {
    templateDrafts[templateLang] = invitationTemplate.text;
    return WorkspaceSettingsSave(
      expectedModifiedAt: openedAt,
      countryCode: code,
      currencyCode: currency.text.trim(),
      timezone: timezone.text.trim(),
      whatsappGroup: whatsappGroup.text.trim(),
      address: workspaceAddress.text.trim(),
      defaultLocale: defaultLocale,
      deskOpacity: deskOpacity,
      invitationTemplates: Map.of(templateDrafts),
      newMemberDefaults: newMemberDefaults,
    );
  }

  void dispose() {
    currency.dispose();
    timezone.dispose();
    whatsappGroup.dispose();
    workspaceAddress.dispose();
    invitationTemplate.dispose();
  }
}
