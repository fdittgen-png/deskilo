// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/invite_uri.dart';
import '../../providers/workspace_providers.dart';
import '../qr_png.dart';
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

  /// The personal admin invitation minted for THIS screen visit (#319).
  /// Single-use on the server, so the segment mints one on first entry
  /// and the owner mints another per additional admin.
  String? _adminCode;
  bool _minting = false;

  Future<void> _mintAdminCode() async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || _minting) return;
    setState(() => _minting = true);
    String? code;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'create admin invitation failed',
      errorText: l10n.inviteCreateFailed,
      action: () async {
        code = await ref
            .read(workspaceRepositoryProvider)
            .createInvitation(workspace.id, isAdmin: true);
      },
    );
    if (!mounted) return;
    setState(() {
      _minting = false;
      if (ok) _adminCode = code;
    });
  }

  Future<void> _editCode(BuildContext context) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final controller = TextEditingController(text: workspace.inviteCode);
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.workspaceCodeEdit),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
          ],
          decoration: InputDecoration(
            labelText: l10n.workspaceCodeLabel,
            helperText:
                l10n.workspaceCodeHint,
            suffixIcon:
                HelpDot(l10n.helpTopicWorkspaceId,
                  anchor: HelpAnchor.workspaceCode,
                ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('workspace-code-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('workspace-code-save'),
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !context.mounted) return;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'set workspace code failed',
      errorText: l10n.workspaceCodeRejected,
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
    final l10n = context.l10n;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'QR share failed',
      errorText: l10n.workspaceGenericError,
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
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final isOwner = ref.watch(myMemberProvider).value?.actsAsOwner ?? false;

    if (workspace == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.workspaceCodeTitle),
        ),
        body: const LoadingView(),
      );
    }

    final isAdminInvite = _role == InviteRole.admin && isOwner;
    final code = isAdminInvite ? _adminCode : workspace.inviteCode;
    final payload = code == null
        ? null
        : InviteUriCodec.encode(
            code: code,
            role: isAdminInvite ? InviteRole.admin : InviteRole.user,
            // #1652 — the QR names the server it was issued on.
            target: ref.watch(activeBackendProvider).value,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workspaceCodeTitle),
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
              if (isOwner) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SegmentedButton<InviteRole>(
                        segments: [
                          ButtonSegment(
                            value: InviteRole.user,
                            icon: const Icon(Icons.person_outline),
                            label: Text(
                              l10n.inviteRoleMember,
                            ),
                          ),
                          ButtonSegment(
                            value: InviteRole.admin,
                            icon: const Icon(Icons.shield_outlined),
                            label: Text(
                              l10n.inviteRoleAdmin,
                            ),
                          ),
                        ],
                        selected: {_role},
                        onSelectionChanged: (selection) {
                          setState(() => _role = selection.first);
                          if (selection.first == InviteRole.admin &&
                              _adminCode == null) {
                            unawaited(_mintAdminCode());
                          }
                        },
                      ),
                    ),
                    HelpDot(l10n.helpTopicWorkspaceId,
                      anchor: HelpAnchor.workspaceCode,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              if (code == null || payload == null) ...[
                // Admin segment while the personal code is minted (or
                // after a failed mint — the retry button re-mints).
                SizedBox(
                  height: 240,
                  child: Center(
                    child: _minting
                        ? const CircularProgressIndicator()
                        : OutlinedButton.icon(
                            key: const ValueKey('admin-invite-retry'),
                            onPressed: _mintAdminCode,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.inviteAdminNewCode),
                          ),
                  ),
                ),
              ] else ...[
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
                    ? (l10n.inviteAdminExplainer)
                    : (l10n.workspaceCodeExplainer),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('workspace-code-copied'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!context.mounted) return;
                      AppSnack.success(
                        context,
                        l10n.workspaceCodeCopied,
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(
                      l10n.workspaceCodeCopy,
                    ),
                  ),
                  if (!isAdminInvite) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      key: const ValueKey('workspace-code-edit'),
                      onPressed: () => _editCode(context),
                      icon: const Icon(Icons.edit),
                      label: Text(
                        l10n.workspaceCodeEdit,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('workspace-code-share-png'),
                onPressed: () => _sharePng(context, code, payload),
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  l10n.workspaceCodeSharePng,
                ),
              ),
              if (isAdminInvite) ...[
                const SizedBox(height: 12),
                // Each admin invitation is single-use — mint the next
                // one right here for the next person.
                OutlinedButton.icon(
                  key: const ValueKey('admin-invite-new'),
                  onPressed: _minting ? null : _mintAdminCode,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.inviteAdminNewCode),
                ),
              ],
              ],
              const SizedBox(height: 12),
              // Personal invitation (0049): a ready-made explanation of
              // download → account → join, over WhatsApp, SMS, or any
              // share target, in the invitee's language.
              FilledButton.tonalIcon(
                key: const ValueKey('invite-someone'),
                onPressed: () => showInviteSheet(
                  context,
                  workspace: workspace,
                  role:
                      isAdminInvite ? InviteRole.admin : InviteRole.user,
                ),
                icon: const Icon(Icons.person_add_alt),
                label: Text(l10n.inviteSectionTitle),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.inviteOwnerNote,
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
