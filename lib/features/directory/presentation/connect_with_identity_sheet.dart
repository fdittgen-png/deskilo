// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1834 A — "Connect to <server>" with the identity the person already
// has. Shown when a Discover action (contact, write to the hosts, ask to
// join) needs a server this account is not connected to yet.
//
// The sheet says which host the person signs in to and what connecting
// never grants, opens that server's own sign-in once, waits for its own
// flow's answer (never another flow's), and closes only when the
// connection is saved. A server that cannot take the identity says why,
// and the person may still use an account they already have there.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/federation_handoff.dart';
import '../../../core/backend/secondary_federation.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import 'connection_dialog.dart';

class ConnectWithIdentitySheet extends ConsumerStatefulWidget {
  const ConnectWithIdentitySheet({super.key, required this.intent});
  final SecondaryConnectIntent intent;

  /// Opens the sheet; true once [intent]'s server is connected.
  static Future<bool> show(
    BuildContext context,
    SecondaryConnectIntent intent,
  ) async =>
      await showAppSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ConnectWithIdentitySheet(intent: intent),
      ) ==
      true;

  @override
  ConsumerState<ConnectWithIdentitySheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<ConnectWithIdentitySheet> {
  late final IdentityConnector _connector = ref.read(identityConnectorProvider);
  late final Future<IdentityConnectReadiness> _readiness = _connector.assess(
    widget.intent.target,
  );
  StreamSubscription<SecondaryConnectEvent>? _events;
  String? _flow;
  String? _message;
  bool _busy = false;

  String get _host => Uri.tryParse(widget.intent.target.url)?.host ?? '';

  @override
  void initState() {
    super.initState();
    _events = _connector.events.listen(_onEvent);
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    // A sheet closed while the browser is open abandons its own flow, so
    // a late return is refused rather than connecting behind the screen.
    final flow = _flow;
    if (flow != null) unawaited(_connector.cancel(flow));
    super.dispose();
  }

  void _onEvent(SecondaryConnectEvent event) {
    if (!mounted || event.flow != _flow) return;
    final l10n = context.l10n;
    switch (event.status) {
      case SecondaryConnectStatus.connected:
        _flow = null;
        AppSnack.success(
          context,
          l10n.identityConnectDone(_host),
        );
        Navigator.of(context).pop(true);
      case SecondaryConnectStatus.notSaved:
        setState(() {
          _flow = null;
          _message =
              l10n.identityConnectNotSaved(_host);
        });
      case SecondaryConnectStatus.failed:
        setState(() {
          _flow = null;
          _message = _failureText(l10n, event.failure);
        });
      case SecondaryConnectStatus.cancelled:
        setState(() => _flow = null);
    }
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final l10n = context.l10n;
    try {
      final flow = await _connector.begin(widget.intent);
      if (mounted) setState(() => _flow = flow);
    } on FederationStartFailure catch (e, st) {
      TraceLogger.instance.warn(
        'connections',
        'identity connect not started: ${e.failure.name}',
        stackTrace: st,
      );
      if (mounted) setState(() => _message = _failureText(l10n, e.failure));
    } on IdentityConnectUnavailable catch (e, st) {
      TraceLogger.instance.warn(
        'connections',
        'identity connect unavailable: ${e.reason.name}',
        stackTrace: st,
      );
      if (mounted) setState(() => _message = _unsupportedText(l10n, e.reason));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _existingAccount() async {
    final connected = await showDialog<bool>(
      context: context,
      builder: (_) => ConnectionDialog(
        origin: widget.intent.target.url,
        publicKey: widget.intent.target.key,
      ),
    );
    if (connected == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: FutureBuilder<IdentityConnectReadiness>(
          future: _readiness,
          builder: (context, snapshot) {
            final unsupported = switch (snapshot.error) {
              IdentityConnectUnavailable(:final reason) => reason,
              null => null,
              _ => IdentityConnectUnsupported.unavailable,
            };
            return Column(
              key: const ValueKey('identity-connect-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.identityConnectTitle(_host),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (snapshot.connectionState != ConnectionState.done)
                  const LoadingView()
                else if (unsupported != null)
                  InlineBanner(
                    key: ValueKey(
                      'identity-connect-unsupported-${unsupported.name}',
                    ),
                    icon: Icons.info_outline,
                    severity: InlineBannerSeverity.info,
                    text: _unsupportedText(l10n, unsupported),
                  )
                else ...[
                  Text(
                    key: const ValueKey('identity-connect-explain'),
                    l10n.identityConnectExplain(_host),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_flow != null) ...[
                    Text(
                      key: const ValueKey('identity-connect-waiting'),
                      l10n.identityConnectWaiting,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      key: const ValueKey('identity-connect-cancel'),
                      onPressed: () => _connector.cancel(_flow!),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                  ] else
                    FilledButton(
                      key: const ValueKey('identity-connect-continue'),
                      onPressed: _busy ? null : _continue,
                      child: Text(
                        _message == null
                            ? (l10n.identityConnectContinue)
                            : (l10n.identityConnectRetry),
                      ),
                    ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  InlineBanner(
                    key: const ValueKey('identity-connect-message'),
                    icon: Icons.error_outline,
                    text: _message!,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                if (_flow == null &&
                    snapshot.connectionState == ConnectionState.done)
                  TextButton(
                    key: const ValueKey('identity-connect-existing'),
                    onPressed: _busy ? null : _existingAccount,
                    child: Text(
                      l10n.identityConnectExistingAccount,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _failureText(
    AppLocalizations l10n,
    FederationFailure? failure,
  ) => switch (failure) {
    FederationFailure.wrongAccount =>
      l10n.identityConnectWrongAccount,
    FederationFailure.unlinkedAccount =>
      l10n.identityConnectUnlinked,
    FederationFailure.expired =>
      l10n.identityConnectExpired,
    FederationFailure.network =>
      l10n.identityConnectNetwork,
    FederationFailure.browserUnavailable =>
      l10n.identityConnectBrowser,
    FederationFailure.providerMissing =>
      l10n.identityConnectNoDeskiloSignIn,
    _ =>
      l10n.identityConnectRefused,
  };

  String _unsupportedText(
    AppLocalizations l10n,
    IdentityConnectUnsupported reason,
  ) => switch (reason) {
    IdentityConnectUnsupported.noSharedIdentity =>
      l10n.identityConnectNoSharedIdentity,
    IdentityConnectUnsupported.targetWithoutDeskiloSignIn =>
      l10n.identityConnectNoDeskiloSignIn,
    IdentityConnectUnsupported.differentAuthority =>
      l10n.identityConnectDifferentAuthority,
    IdentityConnectUnsupported.serverUnsupported =>
      l10n.identityConnectServerUnsupported,
    IdentityConnectUnsupported.currentServer =>
      l10n.identityConnectCurrentServer,
    IdentityConnectUnsupported.unavailable =>
      l10n.identityConnectUnavailable,
  };
}
