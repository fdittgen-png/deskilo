// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../l10n/app_localizations.dart';

/// #780 — the Settings row that opens the Server screen: which Supabase
/// instance this device talks to (the app's own by default).
class BackendSettingsTile extends ConsumerWidget {
  const BackendSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final endpoint = ref.watch(activeBackendProvider).value;
    final isDefault = endpoint == null || ActiveBackend.isDefault(endpoint);
    return ListTile(
      key: const ValueKey('backend-server-tile'),
      leading: const Icon(Icons.dns_outlined),
      title: HelpDotTitle(
        l10n?.backendServerTitle ?? 'Server',
        l10n?.helpTopicServer ?? 'your own server',
      ),
      subtitle: Text(
        endpoint == null
            ? ''
            : isDefault
                ? (l10n?.backendServerDefault(endpoint.host) ??
                    "The app's own server (${endpoint.host})")
                : (l10n?.backendServerCustom(endpoint.host) ??
                    'Your own server (${endpoint.host})'),
      ),
      onTap: () => context.push('/server'),
    );
  }
}
