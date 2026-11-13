// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/phone/phone_entry.dart';
import '../../../../core/share/text_sharer.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/adaptive/task_surface.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/phone_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/personal_info.dart';
import '../../application/assign_role.dart';
import '../../domain/invitation_message.dart';
import '../../domain/invite_uri.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import 'invite_roles_picker.dart';

/// The five help/app languages, by endonym — the invitee reads the
/// message, so the sender picks THEIR language, defaulting to the app's.
const inviteLanguages = <String, String>{
  'en': 'English',
  'fr': 'Français',
  'de': 'Deutsch',
  'es': 'Español',
  'it': 'Italiano',
};

/// Builds the invitation text for [languageCode] (0049): the workspace's
/// custom template when set — its {tag}s filled — otherwise the localized
/// built-in message explaining download → account → join.
///
/// [monospaceCode] wraps the code in WhatsApp's ```…``` monospace markers
/// (#318) so it renders as a visually distinct code; [InviteUriCodec.
/// extractCode] strips the markers back out when the whole message is
/// pasted into the join field.
String buildInvitationMessage({
  required Workspace workspace,
  required String code,
  required InviteRole role,
  required String languageCode,
  String firstName = '',
  String lastName = '',
  String phone = '',
  bool monospaceCode = false,
  BackendEndpoint? target,
}) {
  // #1652 — with [target], the link names the server it was issued on.
  final link = InviteUriCodec.encode(code: code, role: role, target: target);
  final shownCode = monospaceCode ? '```$code```' : code;
  final l10n = lookupAppLocalizations(Locale(languageCode));
  // #486 — the chosen language's own template wins; the legacy single
  // template is the fallback for every language; else the built-in.
  final perLocale =
      ((workspace.invitationTemplates[languageCode] as String?) ?? '')
          .trim();
  final template = perLocale.isNotEmpty
      ? perLocale
      : workspace.invitationTemplate.trim();
  if (template.isEmpty) {
    return l10n.invitationDefaultTemplate(
      firstName.isEmpty ? '' : ' $firstName',
      workspace.name,
      shownCode,
      StoreLinks.downloadLine,
      link,
    );
  }
  return fillInvitationTemplate(template, {
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'workspaceName': workspace.name,
    'workspaceId': shownCode,
    'inviteLink': link,
    'downloadUrl': StoreLinks.downloadLine,
    'role': role == InviteRole.admin
        ? (l10n.inviteRoleAdmin)
        : (l10n.inviteRoleMember),
  });
}

/// Opens the invite sheet for the current invite tab (member or admin).
/// Every send mints its own personal, single-use invitation code (#319)
/// — the workspace ID is never what an invitation carries. [asTask]
/// (#3618): the same form as a short task, a dialog at the desk.
Future<void> showInviteSheet(
  BuildContext context, {
  required Workspace workspace,
  required InviteRole role,
  String? memberId,
  PersonalInfo? identity,
  bool asTask = false,
}) => asTask
    ? showTask<void>(
        context,
        size: TaskSize.short,
        builder: (_) => _InviteSheet(workspace: workspace, role: role),
      )
    : showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(
        workspace: workspace,
        role: role,
        memberId: memberId,
        identity: identity,
      ),
    );

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({
    required this.workspace,
    required this.role,
    this.memberId,
    this.identity,
  });

  final Workspace workspace;
  final InviteRole role;

  /// #887 — the managed member this invitation hands over; the code it
  /// mints claims that profile instead of creating a new member.
  final String? memberId;

  /// The managed identity, pre-filling the name and phone fields.
  final PersonalInfo? identity;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();

  /// #3650 — the country a national number is read in.
  final _phoneCountry = TextEditingController();
  String? _phoneError;

  /// #1119 — whether this person should also reach production.
  ///
  /// The choice is two-way and not three: 0185's invariant is
  /// `prod ⊆ dev`, because the dev twin is where an admin rehearses and
  /// somebody who exists only in prod cannot be rehearsed against. The
  /// real question is "does this person touch production", and that has
  /// two answers.
  bool _alsoProd = false;

  /// #2085 — the workspace's own roles the person holds on arrival.
  Set<String> _roleKeys = const {};

  /// #486 — the WORKSPACE's configured language is the default; the
  /// sender still overrides per send. Null = not yet touched → resolved
  /// at build (workspace language, else the app's).
  String? _language;

  /// #486 — the workspace's configured language when set (and known),
  /// else the sender's app language.
  String _defaultLanguage(BuildContext context) {
    final configured = widget.workspace.defaultLocale;
    if (inviteLanguages.containsKey(configured)) return configured;
    return Localizations.localeOf(context).languageCode;
  }

  @override
  void initState() {
    super.initState();
    final identity = widget.identity;
    if (identity != null) {
      _firstName.text = identity.firstName;
      _lastName.text = identity.lastName;
      _phone.text = identity.phone;
      _phoneCountry.text = identity.countryCode;
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _phoneCountry.dispose();
    super.dispose();
  }

  /// Mints a fresh personal, single-use invitation (#319) and composes
  /// the message around its code. Every send button mints its own code —
  /// a code is one person's, for one join, in the role of this sheet.
  /// Null when minting failed (already traced + snackbarred).
  Future<String?> _composeWithFreshCode({required bool monospace}) async {
    final l10n = context.l10n;
    String? code;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'create invitation failed',
      errorText: l10n.inviteCreateFailed,
      action: () async {
        code = await ref.read(workspaceRepositoryProvider).createInvitation(
              widget.workspace.id,
              isAdmin: widget.role == InviteRole.admin,
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              memberId: widget.memberId,
              alsoProd: _alsoProd,
            );
        await setInvitationRoles(ref,
            workspaceId: widget.workspace.id,
            code: code!,
            roleKeys: _offersRoles ? _roleKeys : const {});
      },
    )) {
      return null;
    }
    if (!mounted) return null;
    return buildInvitationMessage(
      workspace: widget.workspace,
      code: code!,
      role: widget.role,
      languageCode:
          _language ?? _defaultLanguage(context),
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      phone: _phone.text.trim(),
      monospaceCode: monospace,
      target: ref.read(activeBackendProvider).value,
    );
  }

  /// #2085 — a new member's invitation can carry roles; an Administrator
  /// invitation is the Administrator, and a handover carries the profile.
  bool get _offersRoles {
    final features = ref.read(enabledFeaturesSyncProvider);
    return widget.role != InviteRole.admin &&
        widget.memberId == null &&
        features.contains(WorkspaceFeature.roleAssignment) &&
        features.contains(WorkspaceFeature.customRoles);
  }

  /// #3650 — the typed number, read in its country; a message goes to it
  /// only once validated, and without a number to a contact the person
  /// picks in the app. Null after saying in words why it cannot be sent
  /// to (and before a code is minted).
  PhoneEntry? _recipient() {
    final entry = phoneEntryOf(_phone, _phoneCountry);
    final problem = entry.extension.isNotEmpty && entry.isValidated
        ? context.l10n.phoneExtensionNoMessage
        : phoneProblemText(context.l10n, entry);
    setState(() => _phoneError = problem);
    return problem == null ? entry : null;
  }

  Future<void> _send(
    Uri Function(String message) uriOf, {
    required bool monospace,
  }) async {
    final l10n = context.l10n;
    final message = await _composeWithFreshCode(monospace: monospace);
    if (message == null || !mounted) return;
    final opened = await ref.read(linkLauncherProvider)(uriOf(message));
    if (!mounted) return;
    if (!opened) {
      // No handler (e.g. WhatsApp not installed) — the message is not
      // lost: it lands on the clipboard for any app.
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      AppSnack.info(
        context,
        l10n.inviteSendFailed,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _whatsapp() async {
    final to = _recipient();
    if (to == null) return;
    await _send(
      // WhatsApp renders ```…``` as monospace, so the personal code
      // reads as a code (#318).
      (message) => to.isEmpty
          ? whatsappShare(message)
          : whatsappLink(to, text: message)!,
      monospace: true,
    );
  }

  Future<void> _sms() async {
    final to = _recipient();
    if (to == null) return;
    await _send(
      (message) => to.isEmpty ? smsShare(message) : smsLink(to, body: message)!,
      monospace: false,
    );
  }

  Future<void> _share() async {
    final message = await _composeWithFreshCode(monospace: false);
    if (message == null || !mounted) return;
    await ref.read(textSharerProvider)(message);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected =
        _language ?? _defaultLanguage(context);
    // Only a DEV workspace that HAS a twin can offer the choice: joining
    // a prod workspace already reaches production, and the 0185 mirror
    // adds the dev side by itself. Asking a question with one possible
    // answer is worse than not asking it.
    final canChooseEnvironments = ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.memberEnvironments) &&
        widget.workspace.pairId.isNotEmpty &&
        widget.workspace.environment == 'dev';
    return SheetShell(
      title: l10n.inviteSectionTitle,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('invite-first-name'),
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.inviteFirstNameLabel,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              key: const ValueKey('invite-last-name'),
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText:
                    l10n.inviteLastNameLabel,
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        PhoneField(
          number: _phone,
          country: _phoneCountry,
          label: l10n.invitePhoneLabel,
          fieldKey: 'invite-phone',
          error: _phoneError,
          onChanged: () {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
        ),
        if (canChooseEnvironments) ...[
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            key: const ValueKey('invite-also-prod'),
            contentPadding: EdgeInsets.zero,
            value: _alsoProd,
            onChanged: (value) => setState(() => _alsoProd = value),
            title: Text(l10n.inviteAlsoProdTitle),
            subtitle: Text(
              l10n.inviteAlsoProdSubtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        if (_offersRoles)
          InviteRolesPicker(
            key: const ValueKey('invite-roles-picker'),
            selected: _roleKeys,
            onChanged: (keys) => setState(() => _roleKeys = keys),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.inviteLanguageLabel,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final entry in inviteLanguages.entries)
              ChoiceChip(
                key: ValueKey('invite-lang-${entry.key}'),
                label: Text(entry.value),
                selected: selected == entry.key,
                onSelected: (_) => setState(() => _language = entry.key),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('invite-whatsapp'),
              onPressed: _whatsapp,
              icon: const Icon(Icons.chat_outlined),
              label: Text(l10n.whatsappTitle),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('invite-sms'),
              onPressed: _sms,
              icon: const Icon(Icons.sms_outlined),
              label: Text(l10n.inviteViaSms),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('invite-share'),
              onPressed: _share,
              icon: const Icon(Icons.share_outlined),
              label: Text(l10n.libraryShare),
            ),
          ),
        ]),
      ],
    );
  }
}
