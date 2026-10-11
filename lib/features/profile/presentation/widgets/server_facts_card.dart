// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/backend/instance_facts.dart';
import '../../../../core/backend/schema_version.dart';
import '../../../../core/instance/schema_compatibility.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import 'server_full_check.dart';

/// #1309 S1 — which instance this device uses, who owns it, and whether it
/// is current, answered without any credential.
///
/// DesKilo keeps no access to a customer's project: the wizard created it
/// in their own Supabase organization with their token, and held that
/// token in memory only. So the ownership line is a fact to show, not a
/// promise to keep — and the dashboard link opens Supabase's own sign-in.
class ServerFactsCard extends ConsumerWidget {
  const ServerFactsCard({
    super.key,
    required this.endpoint,
    required this.isDefault,
    this.lastSuccessfulTest,
  });

  final BackendEndpoint endpoint;
  final bool isDefault;

  /// When a connection test last answered ok on this screen.
  final DateTime? lastSuccessfulTest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final projectRef = isDefault ? null : supabaseProjectRef(endpoint.host);
    final version = ref.watch(schemaCompatibilityProvider).value;
    return Card(
      key: const ValueKey('backend-facts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDefault)
            ListTile(
              key: const ValueKey('backend-ownership'),
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(projectRef == null
                  ? (l10n.backendOwnServer)
                  : (l10n.backendProjectRef(projectRef))),
              subtitle: Text(projectRef == null
                  ? (l10n.backendOwnershipOther)
                  : (l10n.backendOwnership)),
            ),
          if (projectRef != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: TextButton.icon(
                  key: const ValueKey('backend-open-dashboard'),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.backendOpenDashboard),
                  onPressed: () => ref
                      .read(linkLauncherProvider)(supabaseDashboardUri(projectRef)),
                ),
              ),
            ),
          if (projectRef != null) ServerFullCheck(projectRef: projectRef),
          if (version != null)
            ListTile(
              key: const ValueKey('backend-version'),
              leading: Icon(switch (version) {
                SchemaCompatibility.current => Icons.check_circle_outline,
                SchemaCompatibility.behind => Icons.system_update_alt,
                SchemaCompatibility.ahead => Icons.upgrade,
                SchemaCompatibility.unknown => Icons.help_outline,
              }),
              title: Text(_versionTitle(l10n, version)),
              subtitle: version == SchemaCompatibility.behind
                  ? Text(l10n.backendVersionBehindHow)
                  : null,
            ),
          if (lastSuccessfulTest != null)
            ListTile(
              key: const ValueKey('backend-last-ok'),
              leading: const Icon(Icons.network_check),
              title: Text(l10n.backendLastOk(
                      TimeOfDay.fromDateTime(lastSuccessfulTest!)
                          .format(context))),
            ),
        ],
      ),
    );
  }

  static String _versionTitle(
          AppLocalizations l10n, SchemaCompatibility version) =>
      switch (version) {
        SchemaCompatibility.current =>
          l10n.backendVersionCurrent(requiredSchemaVersion),
        SchemaCompatibility.behind =>
          l10n.backendVersionBehind(requiredSchemaVersion),
        SchemaCompatibility.ahead => l10n.backendVersionAhead,
        SchemaCompatibility.unknown => l10n.backendVersionUnknown,
      };
}

/// "Use the app's server", and the sentence that says what it does NOT do:
/// it changes this device only and calls no Management API (#1309 S3).
class ServerResetAction extends StatelessWidget {
  const ServerResetAction({super.key, required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          key: const ValueKey('backend-reset'),
          onPressed: onReset,
          child: Text(l10n.backendServerReset),
        ),
        Text(
          key: const ValueKey('backend-reset-hint'),
          l10n.backendResetDeviceOnly,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
