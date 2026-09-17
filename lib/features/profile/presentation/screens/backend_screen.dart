// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/backend/backend_uri.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/sign_out.dart';
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
class BackendScreen extends ConsumerStatefulWidget {
  const BackendScreen({super.key});

  @override
  ConsumerState<BackendScreen> createState() => _BackendScreenState();
}

class _BackendScreenState extends ConsumerState<BackendScreen> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _prefilled = false;
  bool _testing = false;
  BackendProbeResult? _result;
  DateTime? _lastOk;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final endpoint = ref.watch(activeBackendProvider).value;
    final isDefault = endpoint == null || ActiveBackend.isDefault(endpoint);
    if (!_prefilled && endpoint != null) {
      _prefilled = true;
      if (!isDefault) {
        _url.text = endpoint.url;
        _key.text = endpoint.key;
      }
    }
    final topic = l10n?.helpTopicServer ?? 'your own server';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.backendServerTitle ?? 'Server'),
        actions: [HelpDot(topic,
          anchor: HelpAnchor.backendServer,
        )],
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
              title: Text(l10n?.backendCurrentTitle ?? 'This device uses'),
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
          if (endpoint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ServerFactsCard(
              endpoint: endpoint,
              isDefault: isDefault,
              lastSuccessfulTest: _lastOk,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          BackendHowTo(topic: topic),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('backend-scan'),
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l10n?.backendScan ?? 'Scan a server QR'),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _field(
            key: const ValueKey('backend-url-field'),
            controller: _url,
            label: l10n?.backendUrlLabel ?? 'Project URL',
            hint: 'https://xxxxxxxx.supabase.co',
            topic: topic,
            keyboard: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.sm),
          _field(
            key: const ValueKey('backend-key-field'),
            controller: _key,
            label: l10n?.backendKeyLabel ?? 'Publishable key',
            hint: 'sb_publishable_…',
            topic: topic,
          ),
          const SizedBox(height: AppSpacing.sm),
          // #1194 — every other button on this screen runs the full
          // width; this one sat half-width and left-aligned, so the
          // column's right edge broke on the one row that matters most.
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
              key: const ValueKey('backend-test'),
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check),
              label: Text(_testing
                  ? (l10n?.backendTesting ?? 'Testing…')
                  : (l10n?.backendTest ?? 'Test the connection')),
              ),
            ),
          ]),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                key: const ValueKey('backend-test-result'),
                backendProbeText(l10n, _result!),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _result == BackendProbeResult.ok
                          ? scheme.primary
                          : scheme.error,
                    ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n?.backendServerRestartHint ??
                'The app signs you out and applies the change on the next '
                    'start.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const ValueKey('backend-save'),
            onPressed: _save,
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
          if (!isDefault) ...[
            const SizedBox(height: AppSpacing.sm),
            ServerResetAction(onReset: () => _apply(null)),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required String topic,
    TextInputType? keyboard,
  }) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboard,
      onChanged: (_) => setState(() => _result = null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n?.backendPaste ?? 'Paste',
              icon: const Icon(Icons.content_paste, size: 20),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text?.trim();
                if (text == null || text.isEmpty) return;
                setState(() {
                  controller.text = text;
                  _result = null;
                });
              },
            ),
            HelpDot(topic,
              anchor: HelpAnchor.backendServer,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scan() async {
    final l10n = AppLocalizations.of(context);
    BackendEndpoint? found;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SheetShell(
        title: l10n?.backendScan ?? 'Scan a server QR',
        children: [
          const SizedBox(height: 12),
          ScanCameraBox(
            cameraKey: const ValueKey('backend-scan-camera'),
            defaultFront: false,
            onCode: (payload) {
              final endpoint = BackendUriCodec.decode(payload);
              if (endpoint == null) return;
              found = endpoint;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (found == null) {
      AppSnack.info(
        context,
        l10n?.backendScanNothing ?? 'That QR is not a DesKilo server code.',
      );
      return;
    }
    setState(() {
      _url.text = found!.url;
      _key.text = found!.key;
      _result = null;
    });
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

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context);
    final error = validateBackendEndpoint(_url.text, _key.text);
    if (error != null) {
      AppSnack.error(context, backendErrorText(l10n, error));
      return;
    }
    setState(() {
      _testing = true;
      _result = null;
    });
    final result = await probeBackend(
      BackendEndpoint(_url.text.trim(), _key.text.trim()),
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = result;
      if (result == BackendProbeResult.ok) _lastOk = ref.read(clockProvider).now();
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final error = validateBackendEndpoint(_url.text, _key.text);
    if (error != null) {
      AppSnack.error(context, backendErrorText(l10n, error));
      return;
    }
    await _apply(BackendEndpoint(_url.text.trim(), _key.text.trim()));
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
