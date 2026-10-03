// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/public_network/public_network_negotiator.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_providers.dart';
import 'connection_dialog.dart';
import 'space_offers.dart';
import 'messenger/inquiry_sheet.dart';

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
    // #1847 — the card is read again from its installation, anonymously:
    // what the owner publishes NOW, and nothing to act on once withdrawn.
    // A preview of one's own page, or a source that cannot be reached,
    // keeps the card it was opened with.
    final live = preview || this.workspace.source.isEmpty
        ? null
        : ref.watch(
            publicWorkspaceDetailProvider(
              this.workspace.source,
              this.workspace.key,
              this.workspace.id,
            ),
          );
    final withdrawn = live is AsyncData<PublicWorkspace?> && live.value == null;
    final workspace = live?.value ?? this.workspace;
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
          if (withdrawn)
            Padding(
              padding: AppSpacing.smAll,
              child: Text(
                key: const ValueKey('public-workspace-withdrawn'),
                l?.portalNoLongerPublished ??
                    'This workspace is no longer published.',
              ),
            ),
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
                  !withdrawn &&
                      contact['available'] == true &&
                      contact['user_id'] is String
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
          // #1824 — an inquiry addressed to the SPACE, read by its host
          // roster, which the sheet shows before anything is written.
          // The space's own `spaceInquiries` flag is decided on its
          // server: a space that switched it off answers no roster.
          if (!preview && !withdrawn)
            OutlinedButton.icon(
              key: const ValueKey('write-to-hosts'),
              icon: const Icon(Icons.contact_support_outlined),
              label: Text(l?.messengerWriteToHosts ?? 'Write to the hosts'),
              onPressed: () async {
                if (!await _connected(context, ref) || !context.mounted) return;
                await showInquirySheet(context, workspace);
              },
            ),
          // #1823 — what the space offers: enter, request, copy the e-mail.
          if (!preview && !withdrawn)
            SpaceOffers(
              workspace: workspace,
              onRequest: () async {
                if (!await _connected(context, ref) || !context.mounted) return;
                // #1847 B — an action this app could not negotiate with that
                // server is refused before anything is sent; say so once.
                PublicActionRefusal? refusal;
                final ok = await runGuarded(
                  context,
                  domain: 'workspace',
                  message: 'request public workspace profile failed',
                  errorText:
                      l?.portalActionFailed ??
                      'Could not save this change. Please try again.',
                  action: () async {
                    try {
                      await ref.read(directoryActionsProvider).apply(workspace);
                      // ignore: catch_no_st — rethrows, or hands the typed refusal to the line below, which traces it.
                    } on PublicActionRefusal catch (r) {
                      if (r.reason == PublicRefusalReason.unreachable) rethrow;
                      refusal = r;
                    }
                  },
                );
                if (refusal != null) {
                  TraceLogger.instance.warn(
                    'workspace',
                    'request public workspace profile not negotiated: ${refusal!.reason.name}',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        key: const ValueKey('action-not-negotiated'),
                        content: Text(
                          l?.portalActionNotNegotiated ??
                              'This action is not available between this app and that server. Updating the app may help.',
                        ),
                      ),
                    );
                  }
                  return;
                }
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
