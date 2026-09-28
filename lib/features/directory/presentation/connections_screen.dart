// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/loading_view.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import 'connection_dialog.dart';

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
            for (final row in rows)
              ListTile(
                title: Text(row.endpoint.host),
                subtitle: Text(row.endpoint.url),
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
                          .disconnect(row.endpoint.url),
                    );
                    if (ok && context.mounted) {
                      ref.invalidate(connectedSourcesProvider);
                    }
                  },
                ),
              ),
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
