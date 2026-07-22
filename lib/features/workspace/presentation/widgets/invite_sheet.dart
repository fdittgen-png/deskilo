// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/links/link_launcher.dart';
import '../../../../core/share/text_sharer.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invitation_message.dart';
import '../../domain/invite_uri.dart';
import '../../domain/workspace.dart';
import '../../providers/workspace_providers.dart';

/// The five help/app languages, by endonym — the invitee reads the
/// message, so the sender picks THEIR language, defaulting to the app's.
const _inviteLanguages = <String, String>{
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
}) {
  final link = InviteUriCodec.encode(code: code, role: role);
  final shownCode = monospaceCode ? '```$code```' : code;
  final l10n = lookupAppLocalizations(Locale(languageCode));
  if (workspace.invitationTemplate.trim().isEmpty) {
    return l10n.invitationDefaultTemplate(
      firstName.isEmpty ? '' : ' $firstName',
      workspace.name,
      shownCode,
      StoreLinks.downloadLine,
      link,
    );
  }
  return fillInvitationTemplate(workspace.invitationTemplate, {
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
/// — the workspace ID is never what an invitation carries.
Future<void> showInviteSheet(
  BuildContext context, {
  required Workspace workspace,
  required InviteRole role,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(workspace: workspace, role: role),
    );

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({
    required this.workspace,
    required this.role,
  });

  final Workspace workspace;
  final InviteRole role;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  String? _language;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Mints a fresh personal, single-use invitation (#319) and composes
  /// the message around its code. Every send button mints its own code —
  /// a code is one person's, for one join, in the role of this sheet.
  /// Null when minting failed (already traced + snackbarred).
  Future<String?> _composeWithFreshCode({required bool monospace}) async {
    final l10n = AppLocalizations.of(context);
    String? code;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'create invitation failed',
      errorText: l10n?.inviteCreateFailed ??
          'Could not create the invitation. '
              'Check your connection and try again.',
      action: () async {
        code = await ref.read(workspaceRepositoryProvider).createInvitation(
              widget.workspace.id,
              isAdmin: widget.role == InviteRole.admin,
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
            );
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
          _language ?? Localizations.localeOf(context).languageCode,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      phone: _phone.text.trim(),
      monospaceCode: monospace,
    );
  }

  /// The phone as wa.me digits ('' when none given).
  String get _phoneDigits =>
      _phone.text.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _send(
    Uri Function(String message) uriOf, {
    required bool monospace,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final message = await _composeWithFreshCode(monospace: monospace);
    if (message == null || !mounted) return;
    final opened = await ref.read(linkLauncherProvider)(uriOf(message));
    if (!mounted) return;
    if (!opened) {
      // No handler (e.g. WhatsApp not installed) — the message is not
      // lost: it lands on the clipboard for any app.
      await Clipboard.setData(ClipboardData(text: message));
      messenger.showSnackBar(SnackBar(
        content: Text(l10n?.inviteSendFailed ??
            'Could not open the app for sending. '
                'The message was copied instead.'),
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _whatsapp() => _send(
        // WhatsApp renders ```…``` as monospace, so the personal code
        // reads as a code (#318).
        (message) => Uri.https(
          'wa.me',
          '/${_phoneDigits.isEmpty ? '' : _phoneDigits}',
          {'text': message},
        ),
        monospace: true,
      );

  Future<void> _sms() => _send(
        (message) => Uri(
          scheme: 'sms',
          path: _phoneDigits.isEmpty ? '' : '+$_phoneDigits',
          queryParameters: {'body': message},
        ),
        monospace: false,
      );

  Future<void> _share() async {
    final message = await _composeWithFreshCode(monospace: false);
    if (message == null || !mounted) return;
    await ref.read(textSharerProvider)(message);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected =
        _language ?? Localizations.localeOf(context).languageCode;
    return SheetShell(
      title: l10n?.inviteSectionTitle ?? 'Invite someone',
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('invite-first-name'),
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n?.inviteFirstNameLabel ??
                    'First name (optional)',
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
                    l10n?.inviteLastNameLabel ?? 'Last name (optional)',
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey('invite-phone'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l10n?.invitePhoneLabel ??
                'Phone (optional, with country code)',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n?.inviteLanguageLabel ?? 'Message language',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final entry in _inviteLanguages.entries)
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
              label: Text(l10n?.inviteViaWhatsapp ?? 'WhatsApp'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('invite-sms'),
              onPressed: _sms,
              icon: const Icon(Icons.sms_outlined),
              label: Text(l10n?.inviteViaSms ?? 'SMS'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('invite-share'),
              onPressed: _share,
              icon: const Icon(Icons.share_outlined),
              label: Text(l10n?.inviteViaShare ?? 'Share…'),
            ),
          ),
        ]),
      ],
    );
  }
}
