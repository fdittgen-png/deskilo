// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "invite members": the space's ID and its member QR with
// the workspace-code screen's own copy and share actions, the personal
// invitation that mints a single-use code, and beside them the invitation
// message exactly as the invite sheet builds it, in each of the five
// languages. The preview carries the space's ID where a sent invitation
// carries its own code; everything else is the text the member receives.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../domain/invite_uri.dart';
import '../../domain/workspace.dart';
import '../qr_png.dart';
import 'invite_sheet.dart';
import 'setup_step_layout.dart';

class SetupInviteStep extends ConsumerStatefulWidget {
  const SetupInviteStep({super.key, required this.workspace});
  final Workspace workspace;

  @override
  ConsumerState<SetupInviteStep> createState() => _SetupInviteStepState();
}

class _SetupInviteStepState extends ConsumerState<SetupInviteStep> {
  /// The previewed language; null until the owner picks one.
  final _language = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _language.dispose();
    super.dispose();
  }

  /// The workspace's language when it is one of the five, else the app's:
  /// the invite sheet's own default.
  String _defaultLanguage(BuildContext context) {
    final configured = widget.workspace.defaultLocale;
    if (inviteLanguages.containsKey(configured)) return configured;
    return Localizations.localeOf(context).languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final code = workspace.inviteCode;
    final target = ref.watch(activeBackendProvider).value;
    final payload = InviteUriCodec.encode(
      code: code,
      role: InviteRole.user,
      target: target,
    );
    return SetupStepLayout(
      form: _InviteForm(workspace: workspace, code: code, payload: payload),
      preview: ValueListenableBuilder<String?>(
        valueListenable: _language,
        builder: (context, picked, _) {
          final language = picked ?? _defaultLanguage(context);
          return _MessagePreview(
            language: language,
            onLanguage: (l) => _language.value = l,
            message: buildInvitationMessage(
              workspace: workspace,
              code: code,
              role: InviteRole.user,
              languageCode: language,
              target: target,
            ),
          );
        },
      ),
    );
  }
}

class _InviteForm extends StatelessWidget {
  const _InviteForm({
    required this.workspace,
    required this.code,
    required this.payload,
  });

  final Workspace workspace;
  final String code;
  final String payload;

  Future<void> _copy(BuildContext context) async {
    final copied = context.l10n.workspaceCodeCopied;
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    AppSnack.success(context, copied);
  }

  /// The QR as a print-ready PNG, to the system share sheet, as the
  /// workspace-code screen hands it out.
  Future<void> _sharePng(BuildContext context) => runGuarded(
    context,
    domain: 'workspace',
    message: 'setup QR share failed',
    errorText: context.l10n.setupInviteShareFailed,
    action: () async {
      final bytes = await buildQrPng(payload);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: ['deskilo-$code.png'],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('invite')),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            color: Colors.white,
            padding: AppSpacing.lgAll,
            child: QrImageView(
              key: const ValueKey('setup-invite-qr'),
              data: payload,
              semanticsLabel: payload,
              size: 200,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SelectableText(
          code,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 3),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.workspaceCodeExplainer,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('setup-invite-copy'),
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy),
              label: Text(l10n.workspaceCodeCopy),
            ),
            OutlinedButton.icon(
              key: const ValueKey('setup-invite-share-png'),
              onPressed: () => _sharePng(context),
              icon: const Icon(Icons.image_outlined),
              label: Text(l10n.workspaceCodeSharePng),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('setup-invite-someone'),
              onPressed: () => showInviteSheet(
                context,
                workspace: workspace,
                role: InviteRole.user,
              ),
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.inviteSectionTitle),
            ),
          ],
        ),
      ],
    );
  }
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({
    required this.language,
    required this.onLanguage,
    required this.message,
  });

  final String language;
  final ValueChanged<String> onLanguage;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupInvitePreviewTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.inviteLanguageLabel, style: theme.textTheme.bodySmall),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final entry in inviteLanguages.entries)
              ChoiceChip(
                key: ValueKey('setup-invite-lang-${entry.key}'),
                label: Text(entry.value),
                selected: language == entry.key,
                onSelected: (_) => onLanguage(entry.key),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: AppSpacing.lgAll,
            child: SelectableText(
              message,
              key: const ValueKey('setup-invite-message'),
            ),
          ),
        ),
        Text(l10n.setupInvitePreviewNote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
