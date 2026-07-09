// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/qr_png.dart';
import '../../providers/workspace_providers.dart';

/// Owner surface (#88): the workspace ID as text + QR. Another phone scans
/// the QR (or types the ID) and connects to this workspace.
class WorkspaceCodeScreen extends ConsumerWidget {
  const WorkspaceCodeScreen({super.key});

  Future<void> _editCode(BuildContext context, WidgetRef ref) async {
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
    if (code == null || code.isEmpty) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setWorkspaceCode(workspace.id, code);
    } catch (e, st) {
      debugPrint('set workspace code failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'set workspace code failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.workspaceCodeRejected ??
                'That ID was rejected — it must be 4–20 letters or digits '
                    'and not already taken.',
          ),
        ),
      );
      return;
    }
    ref.invalidate(myWorkspacesProvider);
  }

  /// Renders the QR as a PNG and hands it to the system share sheet —
  /// coworking owners print it or pin it to the wall (#112).
  Future<void> _sharePng(BuildContext context, String code) async {
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await buildQrPng(code);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'image/png'),
          ],
          fileNameOverrides: ['deskilo-$code.png'],
        ),
      );
    } catch (e, st) {
      debugPrint('QR share failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'QR share failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.workspaceCodeTitle ?? 'Workspace ID & QR'),
      ),
      body: workspace == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      workspace.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: QrImageView(
                        data: workspace.inviteCode,
                        size: 240,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      workspace.inviteCode,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(letterSpacing: 3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n?.workspaceCodeExplainer ??
                          'Coworkers scan this QR code — or type the ID — '
                              'to join this workspace.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: workspace.inviteCode),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n?.workspaceCodeCopied ?? 'Copied',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: Text(
                            l10n?.workspaceCodeCopy ?? 'Copy ID',
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => _editCode(context, ref),
                          icon: const Icon(Icons.edit),
                          label: Text(
                            l10n?.workspaceCodeEdit ?? 'Change workspace ID',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _sharePng(context, workspace.inviteCode),
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        l10n?.workspaceCodeSharePng ?? 'Share as PNG',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
