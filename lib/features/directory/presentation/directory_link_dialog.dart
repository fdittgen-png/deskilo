// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_providers.dart';
import 'connection_dialog.dart';
import 'connection_outcome_text.dart';

/// #2343 — links a server to the global directory, which lives on the
/// reference deployment. The dialog says where the server stands before
/// anything is written: it carries the directory, it is linked, it can
/// be linked (it answers with spaces this app reads), or it cannot yet.
/// Linking is recorded on the reference server, so it needs the person's
/// account there: this device's own session when it uses that server,
/// else a connection to it, which the dialog offers when it is missing.
class DirectoryLinkDialog extends ConsumerStatefulWidget {
  const DirectoryLinkDialog({super.key, this.initial});

  /// The server the dialog opens on — this device's own, usually.
  final BackendEndpoint? initial;

  @override
  ConsumerState<DirectoryLinkDialog> createState() => _DirectoryLinkState();
}

class _DirectoryLinkState extends ConsumerState<DirectoryLinkDialog> {
  late final _url = TextEditingController(text: widget.initial?.url ?? '');
  late final _key = TextEditingController(text: widget.initial?.key ?? '');
  DirectoryLinkState? _state;
  bool _busy = false, _needsAccount = false;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  BackendEndpoint? get _candidate {
    final url = canonicalBackendUrl(_url.text);
    final key = _key.text.trim();
    if (url == null || validateBackendEndpoint(url, key) != null) return null;
    return BackendEndpoint(url, key);
  }

  void _edited() => setState(() {
    _state = null;
    _needsAccount = false;
  });

  Future<void> _check() async {
    final candidate = _candidate;
    if (candidate == null || _busy) return;
    setState(() => _busy = true);
    DirectoryLinkState? state;
    await runGuarded(
      context,
      domain: 'directory',
      message: 'directory link check failed',
      errorText: AppLocalizations.of(context)?.portalConnectionFailed,
      action: () async {
        state = await ref
            .read(directoryActionsProvider)
            .linkState(candidate.url, candidate.key);
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _state = state;
    });
  }

  Future<void> _link() async {
    final candidate = _candidate;
    if (candidate == null || _busy) return;
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    ConnectionFailure? failure;
    final ok = await runGuarded(
      context,
      domain: 'directory',
      message: 'directory link failed',
      action: () async {
        try {
          await ref
              .read(directoryActionsProvider)
              .register(candidate.url, candidate.key);
          // ignore: catch_no_st
        } on ConnectionFailure catch (f) {
          // trace-exempt: rethrown unchanged; runGuarded traces it.
          failure = f;
          rethrow;
        }
      },
    );
    if (!mounted) return;
    final missing = failure?.reason == ConnectionFailureReason.notConnected;
    setState(() {
      _busy = false;
      _needsAccount = missing;
      if (ok) _state = DirectoryLinkState.linked;
    });
    if (ok) {
      ref.invalidate(publicDirectoryProvider);
      AppSnack.success(context, l.directoryLinkDone);
    } else if (!missing) {
      AppSnack.error(
        context,
        failure == null
            ? l.portalActionFailed
            : connectionFailureText(l, failure!),
      );
    }
  }

  Future<void> _connectReference() async {
    final connected = await showDialog<bool>(
      context: context,
      builder: (_) => ConnectionDialog(
        origin: globalDirectoryEndpoint.url,
        publicKey: globalDirectoryEndpoint.key,
      ),
    );
    if (connected == true && mounted) setState(() => _needsAccount = false);
  }

  String _stateText(AppLocalizations l, DirectoryLinkState state) =>
      switch (state) {
        DirectoryLinkState.directory => l.directoryLinkStateDirectory,
        DirectoryLinkState.linked => l.directoryLinkStateLinked,
        DirectoryLinkState.linkable => l.directoryLinkStateLinkable,
        DirectoryLinkState.unreachable => l.directoryLinkStateUnreachable,
      };

  IconData _stateIcon(DirectoryLinkState state) => switch (state) {
    DirectoryLinkState.directory ||
    DirectoryLinkState.linked => Icons.check_circle_outline,
    DirectoryLinkState.linkable => Icons.add_link,
    DirectoryLinkState.unreachable => Icons.link_off,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = _state;
    final ready = _candidate != null && !_busy;
    return AlertDialog(
      title: Text(l.portalRegisterDirectory),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.directoryLinkIntro),
            AppTextField(
              key: const ValueKey('directory-link-url'),
              controller: _url,
              label: l.backendUrlLabel,
              enabled: !_busy,
              onChanged: (_) => _edited(),
            ),
            AppTextField(
              key: const ValueKey('directory-link-key'),
              controller: _key,
              label: l.backendKeyLabel,
              enabled: !_busy,
              onChanged: (_) => _edited(),
            ),
            if (state != null)
              ListTile(
                key: ValueKey('directory-link-state-${state.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(_stateIcon(state)),
                title: Text(_stateText(l, state)),
              ),
            if (_needsAccount) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.directoryLinkNeedsAccount,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('directory-link-connect'),
                  onPressed: _connectReference,
                  child: Text(l.directoryLinkConnect),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('directory-link-close'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
        OutlinedButton(
          key: const ValueKey('directory-link-check'),
          onPressed: ready ? _check : null,
          child: Text(l.directoryLinkCheck),
        ),
        FilledButton(
          key: const ValueKey('directory-link-save'),
          onPressed: ready && state == DirectoryLinkState.linkable
              ? _link
              : null,
          child: Text(l.directoryLinkAction),
        ),
      ],
    );
  }
}
