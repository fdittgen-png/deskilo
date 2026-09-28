// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_providers.dart';
import 'connection_dialog.dart';

class PublicWorkspaceView extends ConsumerWidget {
  const PublicWorkspaceView({
    super.key,
    required this.workspace,
    this.preview = false,
  });
  final PublicWorkspace workspace;
  final bool preview;
  Future<bool> _connected(BuildContext context, WidgetRef ref) async {
    if (ref.read(authStateProvider).value == null) {
      await context.push('/auth');
      return false;
    }
    final registry = ref.read(connectedInstallationsProvider);
    if (workspace.source == registry.origin) return true;
    final sources = await ref.read(connectedSourcesProvider.future);
    if (!context.mounted) return false;
    if (sources.any((s) => s.endpoint.url == workspace.source)) return true;
    return await showDialog<bool>(
          context: context,
          builder: (_) => ConnectionDialog(
            origin: workspace.source,
            publicKey: workspace.key,
          ),
        ) ==
        true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    Widget link(String field, String label) => TextButton.icon(
      icon: const Icon(Icons.open_in_new),
      label: Text(label),
      onPressed: () {
        final uri = Uri.tryParse(workspace.text(field));
        if (uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty) {
          ref.read(linkLauncherProvider)(uri);
        }
      },
    );
    final image = Uri.tryParse(workspace.text('image_url'));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          preview ? (l?.portalPreview ?? 'External view') : workspace.name,
        ),
      ),
      body: ListView(
        padding: AppSpacing.mdAll,
        children: [
          if (image != null &&
              image.scheme == 'https' &&
              image.userInfo.isEmpty)
            Image.network(
              image.toString(),
              height: 160,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) =>
                  const Icon(Icons.business_outlined),
            ),
          Text(
            workspace.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(workspace.source),
          Text(switch (workspace.text('host_type')) {
            'association' => l?.portalAssociation ?? 'Association',
            'company' => l?.portalCompany ?? 'Company',
            _ => l?.portalPerson ?? 'Private host',
          }),
          for (final field in [
            'description',
            'address',
            'email',
            'phone',
            'plans',
          ])
            if (workspace.text(field).isNotEmpty)
              Padding(
                padding: AppSpacing.smAll,
                child: SelectableText(workspace.text(field)),
              ),
          if (workspace.text('website').isNotEmpty)
            link('website', l?.portalWebsite ?? 'Website'),
          if (workspace.text('plan_url').isNotEmpty)
            link('plan_url', l?.portalPublicPlan ?? 'Public floor plan'),
          for (final contact in workspace.contacts)
            ListTile(
              title: Text(contact['name'] as String? ?? ''),
              subtitle: Text(
                contact['owner'] == true
                    ? (l?.portalOwner ?? 'Owner')
                    : (l?.portalAdmin ?? 'Administrator'),
              ),
              trailing:
                  contact['available'] == true && contact['user_id'] is String
                  ? IconButton(
                      tooltip: l?.portalChat ?? 'Chat',
                      icon: const Icon(Icons.chat_outlined),
                      onPressed: preview
                          ? null
                          : () async {
                              if (!await _connected(context, ref) ||
                                  !context.mounted) {
                                return;
                              }
                              await context.push(
                                Uri(
                                  path: '/account-messages',
                                  queryParameters: {
                                    'source': workspace.source,
                                    'recipient': contact['user_id'] as String,
                                    'name': contact['name'] as String? ?? '',
                                  },
                                ).toString(),
                              );
                            },
                    )
                  : null,
            ),
          if (!preview)
            FilledButton.icon(
              icon: const Icon(Icons.person_add_outlined),
              label: Text(
                l?.portalRequestProfile ?? 'Request a workspace profile',
              ),
              onPressed: () async {
                if (!await _connected(context, ref) || !context.mounted) return;
                final ok = await runGuarded(
                  context,
                  domain: 'workspace',
                  message: 'request public workspace profile failed',
                  errorText:
                      l?.portalActionFailed ??
                      'Could not save this change. Please try again.',
                  action: () =>
                      ref.read(directoryActionsProvider).apply(workspace),
                );
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l?.portalRequestSent ?? 'Request sent. The workspace will review your profile.',
                      ),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
