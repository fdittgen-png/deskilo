// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invite_uri.dart';
import '../../domain/qr_png.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/invite_sheet.dart';

/// Owner surface (#88): role-scoped invites. Every invite is bound to a
/// role — the member QR carries the workspace ID, the admin QR its own
/// secret code — and there is deliberately no owner invite: ownership is
/// only granted by an owner in Members & plans.
class WorkspaceCodeScreen extends ConsumerStatefulWidget {
  const WorkspaceCodeScreen({super.key});

  @override
  ConsumerState<WorkspaceCodeScreen> createState() =>
      _WorkspaceCodeScreenState();
}

class _WorkspaceCodeScreenState extends ConsumerState<WorkspaceCodeScreen> {
  InviteRole _role = InviteRole.user;

  Future<void> _editCode(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final controller = TextEditingController(text: workspace.inviteCode);
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.workspaceCodeEdit ?? 'Change workspace ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
          ],
          decoration: InputDecoration(
            labelText: l10n?.workspaceCodeLabel ?? 'Workspace ID',
            helperText:
                l10n?.workspaceCodeHint ?? '4–20 letters or digits, unique',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !context.mounted) return;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'set workspace code failed',
      errorText: l10n?.workspaceCodeRejected ??
          'That ID was rejected — it must be 4–20 letters or digits '
              'and not already taken.',
      action: () => ref
          .read(workspaceRepositoryProvider)
          .setWorkspaceCode(workspace.id, code),
    )) {
      return;
    }
    ref.invalidate(myWorkspacesProvider);
  }

  /// Renders the QR as a PNG and hands it to the system share sheet —
  /// coworking owners print it or pin it to the wall (#112).
  Future<void> _sharePng(
    BuildContext context,
    String code,
    String payload,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'QR share failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
          final bytes = await buildQrPng(payload);
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(bytes, mimeType: 'image/png'),
              ],
              fileNameOverrides: ['deskilo-$code.png'],
            ),
          );
      },
    )) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final adminCode = ref.watch(adminInviteCodeProvider).value;

    if (workspace == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n?.workspaceCodeTitle ?? 'Workspace ID & QR'),
        ),
        body: const LoadingView(),
      );
    }

    final isAdminInvite = _role == InviteRole.admin && adminCode != null;
    final code = isAdminInvite ? adminCode : workspace.inviteCode;
    final payload = InviteUriCodec.encode(
      code: code,
      role: isAdminInvite ? InviteRole.admin : InviteRole.user,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.workspaceCodeTitle ?? 'Workspace ID & QR'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.xlAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                workspace.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              // The invite is always role-bound; there is no role-less QR
              // and no owner segment by design.
              if (adminCode != null) ...[
                const SizedBox(height: 16),
                SegmentedButton<InviteRole>(
                  segments: [
                    ButtonSegment(
                      value: InviteRole.user,
                      icon: const Icon(Icons.person_outline),
                      label: Text(
                        l10n?.inviteRoleMember ?? 'Member invite',
                      ),
                    ),
                    ButtonSegment(
                      value: InviteRole.admin,
                      icon: const Icon(Icons.shield_outlined),
                      label: Text(
                        l10n?.inviteRoleAdmin ?? 'Admin invite',
                      ),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (selection) =>
                      setState(() => _role = selection.first),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                color: Colors.white,
                padding: AppSpacing.lgAll,
                child: QrImageView(
                  data: payload,
                  // The invite URL doubles as the screen-reader
                  // description — it names the role the QR grants.
                  semanticsLabel: payload,
                  size: 240,
                ),
              ),
              const SizedBox(height: 24),
              // Selectable so the owner can copy the ID with a long
              // press too, not only via the Copy button.
              SelectableText(
                code,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(letterSpacing: 3),
              ),
              const SizedBox(height: 8),
              Text(
                isAdminInvite
                    ? (l10n?.inviteAdminExplainer ??
                        'Whoever scans this QR code — or types this code — '
                            'joins as an admin. Share it only with people '
                            'who should manage this workspace.')
                    : (l10n?.workspaceCodeExplainer ??
                        'Coworkers scan this QR code — or type the ID — '
                            'to join this workspace.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!context.mounted) return;
                      AppSnack.success(
                        context,
                        l10n?.workspaceCodeCopied ?? 'Copied',
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(
                      l10n?.workspaceCodeCopy ?? 'Copy ID',
                    ),
                  ),
                  if (!isAdminInvite) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _editCode(context),
                      icon: const Icon(Icons.edit),
                      label: Text(
                        l10n?.workspaceCodeEdit ?? 'Change workspace ID',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _sharePng(context, code, payload),
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  l10n?.workspaceCodeSharePng ?? 'Share as PNG',
                ),
              ),
              const SizedBox(height: 12),
              // Personal invitation (0049): a ready-made explanation of
              // download → account → join, over WhatsApp, SMS, or any
              // share target, in the invitee's language.
              FilledButton.tonalIcon(
                key: const ValueKey('invite-someone'),
                onPressed: () => showInviteSheet(
                  context,
                  workspace: workspace,
                  code: code,
                  role:
                      isAdminInvite ? InviteRole.admin : InviteRole.user,
                ),
                icon: const Icon(Icons.person_add_alt),
                label: Text(l10n?.inviteSectionTitle ?? 'Invite someone'),
              ),
              const SizedBox(height: 16),
              Text(
                l10n?.inviteOwnerNote ??
                    'There is no owner invite — only an owner can grant '
                        'ownership, in Members & plans.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
