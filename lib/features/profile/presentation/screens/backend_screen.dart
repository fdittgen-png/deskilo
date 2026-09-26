// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/backend/backend_uri.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/sign_out.dart';
import '../widgets/backend_candidate_form.dart';
import '../widgets/backend_how_to.dart';
import '../widgets/server_facts_card.dart';

/// #780 — Settings → Server: which Supabase instance this device talks
/// to, configured entirely in the UI.
///
/// The app's own server stays the default. A community that runs its
/// own Supabase project points the app at it here — and the screen is
/// built so nobody has to type a 40-character key on a phone: paste
/// buttons, a QR the owner shares from this same screen, and a
/// connection test that says WHICH part is wrong before anything is
/// saved (unreachable / wrong key / schema not installed).
///
/// #1651 — three states are kept apart on this screen: the CANDIDATE on
/// the form (BackendCandidateForm), the endpoint SAVED for the next start
/// (the store), and the endpoint this process actually RUNS on
/// (`bootedBackendUrlProvider`). A save that has not been followed by a
/// restart is shown as pending, with the way back.
class BackendScreen extends ConsumerStatefulWidget {
  const BackendScreen({super.key});

  @override
  ConsumerState<BackendScreen> createState() => _BackendScreenState();
}

class _BackendScreenState extends ConsumerState<BackendScreen> {
  DateTime? _lastOk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final endpoint = ref.watch(activeBackendProvider).value;
    final isDefault = endpoint == null || ActiveBackend.isDefault(endpoint);
    final booted = ref.watch(bootedBackendUrlProvider);
    final pending = ref.watch(pendingBackendSwitchProvider).value;
    final switchPending =
        endpoint != null && booted.isNotEmpty && booted != endpoint.url;
    final topic = l10n?.helpTopicServer ?? 'your own server';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.backendServerTitle ?? 'Server'),
        actions: [HelpDot(topic, anchor: HelpAnchor.backendServer)],
      ),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Card(
            key: const ValueKey('backend-status'),
            child: ListTile(
              leading: Icon(
                isDefault ? Icons.cloud_outlined : Icons.dns_outlined,
                color: scheme.primary,
              ),
              title: Text(switchPending
                  ? (l10n?.backendPendingTitle ?? 'Saved for the next start')
                  : (l10n?.backendCurrentTitle ?? 'This device uses')),
              subtitle: Text(endpoint == null
                  ? ''
                  : isDefault
                      ? (l10n?.backendServerDefault(endpoint.host) ??
                          "The app's own server (${endpoint.host})")
                      : (l10n?.backendServerCustom(endpoint.host) ??
                          'Your own server (${endpoint.host})')),
              trailing: endpoint == null
                  ? null
                  : IconButton(
                      key: const ValueKey('backend-share'),
                      tooltip: l10n?.backendShare ?? 'Share this server',
                      icon: const Icon(Icons.qr_code_2),
                      onPressed: () => _share(endpoint),
                    ),
            ),
          ),
          if (switchPending) ...[
            const SizedBox(height: AppSpacing.sm),
            Card(
              key: const ValueKey('backend-pending'),
              child: Padding(
                padding: AppSpacing.mdAll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n?.backendPendingBody(
                            Uri.tryParse(booted)?.host ?? booted,
                            endpoint.host) ??
                        'This session still runs on '
                            '${Uri.tryParse(booted)?.host ?? booted}. '
                            '${endpoint.host} takes over when you close and '
                            'reopen the app.'),
                    if (pending != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        key: const ValueKey('backend-pending-undo'),
                        onPressed: _undo,
                        child: Text(l10n?.backendPendingUndo ?? 'Undo'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (endpoint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ServerFactsCard(
              endpoint: endpoint,
              isDefault: isDefault,
              lastSuccessfulTest: _lastOk,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          BackendCandidateForm(
            topic: topic,
            isDefault: isDefault,
            initial: isDefault ? null : endpoint,
            onApply: _apply,
            onVerified: (at) => setState(() => _lastOk = at),
          ),
          const SizedBox(height: AppSpacing.sm),
          BackendHowTo(topic: topic),
          if (!isDefault) ...[
            const SizedBox(height: AppSpacing.sm),
            ServerResetAction(onReset: () => _apply(null)),
          ],
        ],
      ),
    );
  }

  Future<void> _share(BackendEndpoint endpoint) async {
    final l10n = AppLocalizations.of(context);
    final payload = BackendUriCodec.encode(endpoint);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.backendShare ?? 'Share this server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n?.backendShareHint ??
                  'Members scan this in Settings → Server to point their '
                      'app at the same instance.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Container(
              color: Colors.white,
              padding: AppSpacing.mdAll,
              child: QrImageView(data: payload, size: 220),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: payload));
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(l10n?.backendCopyLink ?? 'Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.commonClose ?? 'Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _undo() async {
    final l10n = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'backend',
      message: 'undo backend switch failed',
      action: () async {
        await ref.read(activeBackendProvider.notifier).undoSwitch();
      },
    );
    if (!ok || !mounted) return;
    AppSnack.success(
      context,
      l10n?.backendPendingUndone ?? 'Undone — the previous server is back.',
    );
  }

  Future<void> _apply(BackendEndpoint? endpoint) async {
    final l10n = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'backend',
      message: 'set backend endpoint failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        await ref.read(activeBackendProvider.notifier).setEndpoint(endpoint);
        // The session was issued by the OTHER instance — keeping it would
        // show a signed-in shell against a server that never heard of
        // this user.
        await signOutAndForget(ref);
      },
    );
    if (!ok || !mounted) return;
    AppSnack.success(
      context,
      l10n?.backendServerSaved ??
          'Saved. Close and reopen the app to use the new server.',
    );
  }
}
