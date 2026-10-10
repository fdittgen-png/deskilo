// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/backend_uri.dart';
import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../providers/directory_providers.dart';
import 'connection_outcome_text.dart';

class ConnectionDialog extends ConsumerStatefulWidget {
  const ConnectionDialog({
    super.key,
    this.origin = '',
    this.publicKey = '',
  });
  final String origin, publicKey;
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

  /// #2343 — fills the two fields from a known server.
  void _fill(BackendEndpoint endpoint) => setState(() {
    _url.text = endpoint.url;
    _key.text = endpoint.key;
  });

  /// #2343 — a `deskilo://server` code an organisation shared, pasted
  /// instead of typing a 40-character key on a phone.
  Future<void> _paste() async {
    final l = AppLocalizations.of(context)!;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final descriptor = BackendUriCodec.decodeDescriptor(data?.text ?? '');
    if (descriptor == null) {
      AppSnack.error(
        context,
        l.serverConnectNoCode,
      );
      return;
    }
    _fill(descriptor.endpoint);
  }

  /// #2343 — leaves the dialog for a route of the app: the server screen
  /// (no account on that server yet: use it here and sign up) or the
  /// instance wizard (a server that does not exist yet).
  void _leaveFor(String location, {Object? extra}) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(location, extra: extra);
  }

  /// The candidate on the form, when it is a well-formed endpoint.
  BackendEndpoint? get _candidate {
    final url = canonicalBackendUrl(_url.text);
    final key = _key.text.trim();
    if (url == null || validateBackendEndpoint(url, key) != null) return null;
    return BackendEndpoint(url, key);
  }

  /// #2343 — joining and creating, above the sign-in form.
  List<Widget> _joinOrCreate(AppLocalizations l) => [
    Text(l.serverConnectIntro),
    Wrap(
      spacing: 8,
      children: [
        ActionChip(
          key: const ValueKey('connection-dialog-reference'),
          avatar: const Icon(Icons.public_outlined, size: 18),
          label: Text(l.serverConnectReference),
          onPressed: _busy ? null : () => _fill(referenceEndpoint),
        ),
        ActionChip(
          key: const ValueKey('connection-dialog-paste-code'),
          avatar: const Icon(Icons.content_paste_outlined, size: 18),
          label: Text(l.serverConnectPasteCode),
          onPressed: _busy ? null : _paste,
        ),
      ],
    ),
  ];

  /// #2343 — the two ways out when this form cannot be used: no account
  /// on that server yet, or no server yet at all.
  List<Widget> _otherWays(AppLocalizations l) {
    final wizard = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.instanceWizard);
    final candidate = _candidate;
    return [
      const SizedBox(height: AppSpacing.sm),
      Text(
        l.serverConnectNoAccount,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          key: const ValueKey('connection-dialog-use-here'),
          onPressed: _busy || candidate == null
              ? null
              : () => _leaveFor(
                  '/server',
                  extra: BackendDescriptor(candidate),
                ),
          child: Text(l.serverConnectUseHere),
        ),
      ),
      if (wizard)
        OutlinedButton.icon(
          key: const ValueKey('connection-dialog-new-instance'),
          onPressed: _busy ? null : () => _leaveFor('/server/new-instance'),
          icon: const Icon(Icons.auto_fix_high_outlined),
          label: Text(l.instanceCreateButton),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l?.portalConnect ?? 'Connect a server'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._joinOrCreate(AppLocalizations.of(context)!),
            TextField(
              key: const ValueKey('connection-dialog-url'),
              controller: _url,
              onChanged: (_) => setState(() {}),
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l?.backendUrlLabel ?? 'Project URL',
              ),
            ),
            TextField(
              key: const ValueKey('connection-dialog-key'),
              controller: _key,
              onChanged: (_) => setState(() {}),
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l?.backendKeyLabel ?? 'Publishable key',
              ),
            ),
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
            ..._otherWays(AppLocalizations.of(context)!),
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
