// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/trace/guarded.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/directory_providers.dart';

class ConnectionDialog extends ConsumerStatefulWidget {
  const ConnectionDialog({
    super.key,
    this.origin = '',
    this.publicKey = '',
    this.publishDirectory = false,
  });
  final String origin, publicKey;
  final bool publishDirectory;
  @override
  ConsumerState<ConnectionDialog> createState() => _ConnectionState();
}

class _ConnectionState extends ConsumerState<ConnectionDialog> {
  late final _url = TextEditingController(text: widget.origin);
  late final _key = TextEditingController(text: widget.publicKey);
  final _email = TextEditingController(), _credential = TextEditingController();
  bool _code = false, _busy = false;
  @override
  void dispose() {
    for (final c in [_url, _key, _email, _credential]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit({bool requestCode = false}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final endpoint = BackendEndpoint(_url.text.trim(), _key.text.trim());
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'account',
      message: 'connect installation failed',
      errorText:
          l10n?.portalConnectionFailed ??
          'Could not connect. Check this server and your sign-in details.',
      action: () async {
        if (validateBackendEndpoint(endpoint.url, endpoint.key) != null) {
          throw StateError('invalid endpoint');
        }
        if (widget.publishDirectory) {
          await ref
              .read(directoryActionsProvider)
              .register(endpoint.url, endpoint.key);
        } else {
          final registry = ref.read(connectedInstallationsProvider);
          if (requestCode) {
            await registry.requestCode(endpoint, _email.text);
          } else {
            await registry.connect(
              endpoint,
              _email.text,
              _credential.text,
              code: _code,
            );
          }
        }
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && requestCode) {
      setState(() => _code = true);
    }
    if (ok && !requestCode) {
      ref.invalidate(connectedSourcesProvider);
      ref.invalidate(publicDirectoryProvider);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.publishDirectory
            ? (l?.portalRegisterDirectory ??
                  'Publish a server in the directory')
            : (l?.portalConnect ?? 'Connect a server'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _url,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l?.backendUrlLabel ?? 'Project URL',
              ),
            ),
            TextField(
              controller: _key,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l?.backendKeyLabel ?? 'Publishable key',
              ),
            ),
            if (!widget.publishDirectory) ...[
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l?.authEmailLabel ?? 'Email',
                ),
              ),
              TextField(
                controller: _credential,
                enabled: !_busy,
                obscureText: !_code,
                decoration: InputDecoration(
                  labelText: _code
                      ? (l?.portalEmailCode ?? 'Email sign-in code')
                      : (l?.authPasswordLabel ?? 'Password'),
                ),
              ),
              SwitchListTile(
                value: _code,
                onChanged: _busy ? null : (v) => setState(() => _code = v),
                title: Text(l?.portalUseCode ?? 'Use an email code'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _submit(requestCode: true),
                child: Text(l?.portalSendCode ?? 'Send sign-in code'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}
