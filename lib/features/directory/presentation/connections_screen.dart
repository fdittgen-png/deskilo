// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/loading_view.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import 'connection_dialog.dart';
import 'connection_outcome_text.dart';

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sources = ref.watch(connectedSourcesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l?.portalConnections ?? 'Connected servers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog<bool>(
          context: context,
          builder: (_) => const ConnectionDialog(),
        ),
        tooltip: l?.portalConnect ?? 'Connect a server',
        child: const Icon(Icons.add),
      ),
      body: switch (sources) {
        AsyncData(value: final rows) => ListView(
          padding: const EdgeInsets.only(bottom: kFabSafeBottom),
          children: [
            ListTile(
              title: Text(
                l?.portalConnectionsHint ?? 'Each server uses its own sign-in. Disconnecting removes its saved access from this account on this device.',
              ),
            ),
            for (final row in rows) _ConnectionTile(row),
          ],
        ),
        AsyncError() => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(connectedSourcesProvider),
            child: Text(l?.commonRetry ?? 'Try again'),
          ),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

/// #1832 A — one connected server with its own state and its own
/// recovery. A server that is down, expired or quarantined says so on its
/// row; the other rows are asked separately and stay usable.
class _ConnectionTile extends ConsumerWidget {
  const _ConnectionTile(this.row);
  final ConnectedInstallation row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final source = row.endpoint.url;
    final health = ref.watch(connectionHealthProvider(source));
    final registry = ref.watch(connectedInstallationsProvider);
    final failure = health.value;
    final status = switch (health) {
      AsyncData(value: null) =>
        registry.sessionNotSaved(source)
            ? (l?.connectionSessionNotSaved ??
                  'The action was done, but this device could not save the '
                      "server's sign-in. You may be asked to sign in again.")
            : (l?.connectionUsable ?? 'Connected'),
      AsyncData(value: final f?) => connectionFailureText(l, f),
      AsyncError() =>
        l?.connectionMalformed ??
            'This server answered something this app cannot read.',
      _ => l?.connectionChecking ?? 'Checking…',
    };
    final key = switch (health) {
      AsyncData(value: null) => 'usable',
      AsyncData(value: final f?) => f.reason.name,
      AsyncError() => 'malformed',
      _ => 'checking',
    };
    final recovery = failure == null
        ? (health.hasError
              ? ConnectionRecovery.retry
              : ConnectionRecovery.none)
        : connectionRecovery(failure.reason);

    Future<void> reconnect() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => ConnectionDialog(
          origin: source,
          publicKey: row.endpoint.key,
        ),
      );
      if (ok == true && context.mounted) {
        ref.invalidate(connectionHealthProvider(source));
      }
    }

    return ListTile(
      key: ValueKey('connection-$source'),
      title: Text(row.endpoint.host),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.endpoint.url),
          Text(
            status,
            key: ValueKey('connection-status-$key'),
            style: failure == null
                ? null
                : TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          if (recovery != ConnectionRecovery.none)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: switch (recovery) {
                ConnectionRecovery.signIn => TextButton(
                  key: const ValueKey('connection-action-signin'),
                  onPressed: reconnect,
                  child: Text(l?.connectionSignInAgain ?? 'Sign in again'),
                ),
                ConnectionRecovery.verify => TextButton(
                  key: const ValueKey('connection-action-verify'),
                  onPressed: reconnect,
                  child: Text(l?.connectionVerifyAgain ?? 'Verify again'),
                ),
                _ => TextButton(
                  key: const ValueKey('connection-action-retry'),
                  onPressed: () =>
                      ref.invalidate(connectionHealthProvider(source)),
                  child: Text(l?.connectionRetry ?? 'Try again'),
                ),
              },
            ),
        ],
      ),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: l?.portalDisconnect ?? 'Disconnect',
        icon: const Icon(Icons.link_off),
        onPressed: () async {
          final ok = await runGuarded(
            context,
            domain: 'account',
            message: 'disconnect installation failed',
            errorText: l?.portalConnectionFailed ?? 'Could not connect. Check this server and your sign-in details.',
            action: () => ref
                .read(connectedInstallationsProvider)
                .disconnect(source),
          );
          if (ok && context.mounted) {
            ref.invalidate(connectedSourcesProvider);
          }
        },
      ),
    );
  }
}
