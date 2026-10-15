// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../app/theme.dart';
import '../../../../core/country/country_catalog.dart';
import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_picker.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/i18n/country_names.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/i18n/workspace_locale_fields.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/l10n/lexicon.dart';
import '../../../../core/locale/report_language.dart';
import '../../../../core/settings/settings.dart';
import '../../../../core/share/file_sharer.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../directory/presentation/admin_visibility_tile.dart';
import '../../../events/providers/event_providers.dart';
import '../../../money/domain/report_data_letters.dart';
import '../../../money/presentation/batch_cover.dart';
import '../../../money/presentation/invoice_documents.dart';
import '../../../money/presentation/report_facts_of.dart';
import '../../../money/presentation/report_layout_actions.dart';
import '../../../money/presentation/report_strings_l10n.dart';
import '../../../money/presentation/widgets/billing_rules_dialog.dart';
import '../../../money/presentation/widgets/dunning_rules_dialog.dart';
import '../../../money/providers/money_providers.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/providers/accessory_providers.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../application/apply_brand_seed.dart';
import '../../application/toggle_workspace_feature.dart';
import '../../domain/booking_granularity.dart';
import '../../domain/invitation_message.dart';
import '../../domain/member.dart';
import '../../domain/new_member_defaults.dart';
import '../../domain/overage_policy.dart';
import '../../domain/payment_instructions.dart';
import '../../domain/space_code_entries.dart';
import '../../domain/space_codes_pdf.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_config_report.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_import.dart';
import '../../domain/workspace_permission.dart';
import '../../domain/workspace_settings_save.dart';
import '../../domain/workspace_xml.dart';
import '../../domain/workspace_xml_configuration.dart';
import '../../providers/workspace_import_providers.dart';
import '../../providers/workspace_providers.dart';
import '../excel_export.dart';
import '../feature_names.dart';
import '../member_labels.dart';
import '../widgets/configuration_transfer_prompt.dart';
import '../widgets/local_setup_views.dart';
import '../widgets/new_member_defaults_tiles.dart';
import '../widgets/reset_confirm_dialog.dart';
import '../widgets/settings_editor.dart';
import '../widgets/space_codes_options_dialog.dart';
import '../widgets/workspace_form_group.dart';
import '../widgets/workspace_own_screens.dart';
import '../widgets/workspace_reports.dart';
import '../workspace_configuration_report_strings.dart';

part 'workspace_settings_screen_part1.dart';
part 'workspace_settings_screen_part2.dart';
part 'workspace_settings_screen_part3.dart';
part 'workspace_settings_screen_part4.dart';

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
    extends ConsumerState<WorkspaceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currency = TextEditingController();
  final _timezone = TextEditingController();
  // #231 — the community's WhatsApp group invite link (directory, #232).
  final _whatsappGroup = TextEditingController();
  final _workspaceAddress = TextEditingController();
  final _invitationTemplate = TextEditingController();
  // 0040 — desk fill opacity percentage (20..100); rides the Save button.
  int _deskOpacity = 100;
  // #1294 — what a newly joining member starts with; rides the Save too.
  // #1563 — null until the separate read lands: never send a fallback.
  NewMemberDefaults? _newMemberDefaults;
  String? _countryCode;
  // #486 — the workspace's own language ('' = sender's app language)
  // and the per-language invitation drafts the chips page through.
  String _defaultLocale = '';
  String _templateLang = 'en';
  final Map<String, String> _templateDrafts = {};
  bool _busy = false;

  static const Map<String, String> _languages = {
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
  DateTime? _openedAt;
  bool _seededDefaults = false;

  @override
  void dispose() {
    _currency.dispose();
    _timezone.dispose();
    _whatsappGroup.dispose();
    _workspaceAddress.dispose();
    _invitationTemplate.dispose();
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
    if (workspace != null && !_seeded) {
      _seeded = true;
      _countryCode = workspace.countryCode;
      _currency.text = workspace.currencyCode;
      _timezone.text = workspace.timezone;
      // #486 — one draft per language; a workspace still on the legacy
      // single template (0049) sees it in every language until it saves.
      final legacy = workspace.invitationTemplate.trim();
      final hasPerLocale = workspace.invitationTemplates.values
          .any((t) => (t as String? ?? '').trim().isNotEmpty);
      for (final lang in _languages.keys) {
        _templateDrafts[lang] = hasPerLocale
            ? ((workspace.invitationTemplates[lang] as String?) ?? '')
            : legacy;
      }
      _defaultLocale = workspace.defaultLocale;
      _templateLang = _languages.containsKey(_defaultLocale)
          ? _defaultLocale
          : 'en';
      _whatsappGroup.text = workspace.whatsappGroup;
      _workspaceAddress.text = workspace.address;
      _invitationTemplate.text = _templateDrafts[_templateLang] ?? '';
      _deskOpacity = workspace.deskOpacity;
      _openedAt = workspace.system.modifiedAt;
    }
    // #1294 — read separately: it lives in billing_rules, not on the
    // workspace row the screen already holds. Seeded once, like the rest —
    // and #1563: until it lands there is nothing to save, so Save omits it.
    final loadedDefaults = ref.watch(newMemberDefaultsProvider).value;
    if (loadedDefaults != null && !_seededDefaults) {
      _seededDefaults = true;
      _newMemberDefaults = loadedDefaults;
    }
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
                  ..._parametersTiles(context, l10n: l10n, workspace: workspace, helpTopic: helpTopic),
                  WorkspaceFormGroup(id: 'tools', title: labels.uxWorkspaceTools, icon: Icons.import_export,
                    children: _toolsTiles(context, l10n: l10n, workspace: workspace, helpTopic: helpTopic)),
                  WorkspaceFormGroup(id: 'danger', title: labels.workspaceDangerZone, icon: Icons.warning_amber, destructive: true,
                    children: _dangerZoneTiles(context, l10n: l10n, workspace: workspace)),
              ]),
            ),
      bottomNavigationBar: workspace == null ? null : WorkspaceSettingsSaveBar(busy: _busy, onSave: () => _save(workspace.id)),
    );
  }

  /// Lets the section extensions rebuild (setState is protected).
  void _update(VoidCallback fn) => setState(fn);

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
