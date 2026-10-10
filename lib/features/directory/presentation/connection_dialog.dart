// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/directory_providers.dart';
import 'connection_outcome_text.dart';

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
    // #1832 A — a typed outcome says what went wrong and what to do; only
    // an error without one falls back to the generic sentence.
    ConnectionFailure? failure;
    final ok = await runGuarded(
      context,
      domain: 'account',
      message: 'connect installation failed',
      action: () async {
        try {
          await _connect(endpoint, requestCode: requestCode);
        // ignore: catch_no_st
        } on ConnectionFailure catch (f) {
          // trace-exempt: rethrown unchanged; runGuarded traces it.
          failure = f;
          rethrow;
        }
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      AppSnack.error(
        context,
        failure != null
            ? connectionFailureText(l10n, failure!)
            : (l10n?.portalConnectionFailed ??
                  'Could not connect. Check this server and your sign-in '
                      'details.'),
      );
    }
    if (ok && requestCode) {
      setState(() => _code = true);
    }
    if (ok && !requestCode) {
      ref.invalidate(connectedSourcesProvider);
      ref.invalidate(connectionHealthProvider(endpoint.url));
      ref.invalidate(publicDirectoryProvider);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _connect(
    BackendEndpoint endpoint, {
    required bool requestCode,
  }) async {
    if (validateBackendEndpoint(endpoint.url, endpoint.key) != null) {
      throw ConnectionFailure(
        endpoint.url,
        ConnectionFailureReason.invalidEndpoint,
      );
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
                autofillHints: const [AutofillHints.email],
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
                key: const ValueKey('connection-dialog-portal-use-code'),
                value: _code,
                onChanged: _busy ? null : (v) => setState(() => _code = v),
                title: Text(l?.portalUseCode ?? 'Use an email code'),
              ),
              TextButton(
                key: const ValueKey('connection-dialog-portal-send-code'),
                onPressed: _busy ? null : () => _submit(requestCode: true),
                child: Text(l?.portalSendCode ?? 'Send sign-in code'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('connection-dialog-text-button'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('connection-dialog-save'),
          onPressed: _busy ? null : _submit,
          child: Text(l?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}
