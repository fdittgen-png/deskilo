// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// The OWNER's WhatsApp-channel configuration (#552) — the how-to and
/// the credentials in one place, the payment-config pattern (#300):
/// per-workspace secrets stored write-only through an owner RPC, never
/// read back. Blank fields keep the stored value, so the phone id can
/// be fixed without re-typing the token.
Future<void> showWhatsappChannelSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _WhatsappChannelSheet(),
    );

class _WhatsappChannelSheet extends ConsumerStatefulWidget {
  const _WhatsappChannelSheet();

  @override
  ConsumerState<_WhatsappChannelSheet> createState() =>
      _WhatsappChannelSheetState();
}

class _WhatsappChannelSheetState
    extends ConsumerState<_WhatsappChannelSheet> {
  final _token = TextEditingController();
  final _phoneId = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    _phoneId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    if (_token.text.trim().isEmpty && _phoneId.text.trim().isEmpty) {
      return;
    }
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'whatsapp channel save failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(workspaceRepositoryProvider).setWhatsappChannel(
            workspace.id,
            token: _token.text.trim(),
            phoneId: _phoneId.text.trim(),
          ),
    )) {
      return;
    }
    ref.invalidate(whatsappMirrorConfiguredProvider);
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n?.whatsappChannelSaved ?? 'WhatsApp channel saved.',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final configured = ref.watch(whatsappMirrorConfiguredProvider).value;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.whatsappChannelTitle ?? 'WhatsApp channel',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(children: [
              Icon(
                configured == true
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                size: 16,
                color: configured == true
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  configured == true
                      ? (l10n?.whatsappChannelConfigured ??
                          'Channel configured — messages mirror to '
                              'WhatsApp.')
                      : (l10n?.whatsappChannelNotConfigured ??
                          'Not configured — messages arrive in-app and '
                              'by push only.'),
                  key: const ValueKey('whatsapp-channel-status'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            // The how-to: what the owner does OUTSIDE the app, once.
            Text(
              l10n?.whatsappChannelHelp ??
                  '1. Create a (free) app on developers.facebook.com '
                      'and add the WhatsApp product.\n'
                      '2. Under WhatsApp → API setup, copy the '
                      'permanent access token and the phone number '
                      'ID.\n'
                      '3. Paste both below — member messages are then '
                      'sent from that number.\n'
                      'Note: WhatsApp only delivers within 24 h of the '
                      'recipient\'s last WhatsApp message to your '
                      'number (their service window).',
              key: const ValueKey('whatsapp-channel-help'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('whatsapp-channel-token'),
              controller: _token,
              obscureText: true,
              decoration: InputDecoration(
                labelText:
                    l10n?.whatsappChannelToken ?? 'Access token',
                helperText: l10n?.whatsappChannelKeepHint ??
                    'Leave blank to keep the stored value.',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('whatsapp-channel-phone'),
              controller: _phoneId,
              decoration: InputDecoration(
                labelText:
                    l10n?.whatsappChannelPhoneId ?? 'Phone number ID',
                helperText: l10n?.whatsappChannelKeepHint ??
                    'Leave blank to keep the stored value.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('whatsapp-channel-save'),
              onPressed: _save,
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
