// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/secondary_federation.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/links/link_launcher.dart';
import '../../../core/public_network/public_network_negotiator.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/personal_kit/me_card.dart';
import '../../../core/ui/server_label.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_providers.dart';
import '../providers/discovery_listing_providers.dart';
import 'connect_with_identity_sheet.dart';
import 'messenger/inquiry_sheet.dart';
import 'saved_place_button.dart';
import 'space_offers.dart';
import 'workspace_feedback.dart';

class PublicWorkspaceView extends ConsumerWidget {
  const PublicWorkspaceView({
    super.key,
    required this.workspace,
    this.preview = false,
    this.personal = false,
  });
  final PublicWorkspace workspace;
  final bool preview;

  /// Opened from Me: the page wears the personal theme.
  final bool personal;

  /// Whether [workspace]'s server can be used for [action] now. A server
  /// this account is not connected to opens the identity sheet (#1834);
  /// [_Connection.now] tells the caller it was connected just now.
  Future<_Connection> _connected(
    BuildContext context,
    WidgetRef ref,
    SecondaryConnectAction action,
  ) async {
    if (ref.read(authStateProvider).value == null) {
      await context.push('/auth');
      return _Connection.none;
    }
    final registry = ref.read(connectedInstallationsProvider);
    if (workspace.source == registry.origin) return _Connection.already;
    final sources = await ref.read(connectedSourcesProvider.future);
    if (!context.mounted) return _Connection.none;
    if (sources.any((s) => s.endpoint.url == workspace.source)) {
      return _Connection.already;
    }
    final connected = await ConnectWithIdentitySheet.show(
      context,
      SecondaryConnectIntent(
        target: BackendEndpoint(workspace.source, workspace.key),
        workspaceId: workspace.id,
        action: action,
      ),
    );
    if (connected) {
      ref
        ..invalidate(connectedSourcesProvider)
        ..invalidate(discoveryListingProvider);
    }
    return connected ? _Connection.now : _Connection.none;
  }

  /// #1834 — connecting is not asking to join: a request made right after
  /// connecting is confirmed once more, with the space's name.
  Future<bool> _confirmApply(BuildContext context) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('identity-connect-confirm-apply'),
            title: Text(l.identityConnectConfirmApply(workspace.name)),
            content: Text(l.identityConnectConfirmApplyBody),
            actions: [
              TextButton(
                key: const ValueKey('identity-connect-cancel-send'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                key: const ValueKey('identity-connect-send'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.identityConnectSend),
              ),
            ],
          ),
        ) ==
        true;
  }

  Widget _link(
    WidgetRef ref,
    PublicWorkspace workspace,
    String field,
    String label,
  ) => TextButton.icon(
    key: ValueKey('public-workspace-view-open-$field'),
    icon: const Icon(Icons.open_in_new),
    label: Text(label),
    onPressed: () {
      final uri = Uri.tryParse(workspace.text(field));
      if (uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty) {
        unawaited(ref.read(linkLauncherProvider)(uri));
      }
    },
  );

  Future<void> _chat(
    BuildContext context,
    WidgetRef ref,
    PublicWorkspace workspace,
    Map<String, Object?> contact,
  ) async {
    if (await _connected(context, ref, SecondaryConnectAction.contact) ==
            _Connection.none ||
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
  }

  Future<void> _writeToHosts(
    BuildContext context,
    WidgetRef ref,
    PublicWorkspace workspace,
  ) async {
    if (await _connected(context, ref, SecondaryConnectAction.inquiry) ==
            _Connection.none ||
        !context.mounted) {
      return;
    }
    await showInquirySheet(context, workspace);
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    PublicWorkspace workspace,
  ) async {
    final l = context.l10n;
    final connection = await _connected(
      context,
      ref,
      SecondaryConnectAction.apply,
    );
    if (connection == _Connection.none || !context.mounted) return;
    if (connection == _Connection.now && !await _confirmApply(context)) {
      return;
    }
    if (!context.mounted) return;
    // #1847 B — an action this app could not negotiate with that
    // server is refused before anything is sent; say so once.
    PublicActionRefusal? refusal;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'request public workspace profile failed',
      errorText: l.portalActionFailed,
      action: () async {
        try {
          await ref.read(directoryActionsProvider).apply(workspace);
        } on PublicActionRefusal catch (r, st) {
          if (r.reason == PublicRefusalReason.unreachable) {
            Error.throwWithStackTrace(r, st);
          }
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
            content: Text(l.portalActionNotNegotiated),
          ),
        );
      }
      return;
    }
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.portalRequestSent)));
    }
  }

  /// What the space published, then its contacts.
  List<Widget> _details(
    BuildContext context,
    WidgetRef ref,
    PublicWorkspace workspace, {
    required bool withdrawn,
  }) {
    final l = context.l10n;
    Widget link(String field, String label) =>
        _link(ref, workspace, field, label);
    final email = workspace.text('email');
    final phone = workspace.text('phone');
    final hasWebsite = workspace.text('website').isNotEmpty;
    final hasPlan = workspace.text('plan_url').isNotEmpty;
    final hasContacts = workspace.contacts.isNotEmpty;
    return [
      for (final field in ['description', 'plans'])
        if (workspace.text(field).isNotEmpty)
          Padding(
            padding: AppSpacing.smAll,
            child: SelectableText(workspace.text(field)),
          ),
      // What the space published to be reached by: one card.
      if (email.isNotEmpty ||
          phone.isNotEmpty ||
          hasWebsite ||
          hasPlan ||
          hasContacts)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: MeCard(
            key: const ValueKey('public-workspace-contact-card'),
            padding: AppSpacing.smAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email.isNotEmpty)
                  Padding(
                    padding: AppSpacing.smAll,
                    child: SelectableText(email),
                  ),
                if (phone.isNotEmpty)
                  Padding(
                    padding: AppSpacing.smAll,
                    child: SelectableText(phone),
                  ),
                if (hasWebsite) link('website', l.portalWebsite),
                if (hasPlan) link('plan_url', l.portalPublicPlan),
                for (final contact in workspace.contacts)
                  ListTile(
                    title: Text(contact['name'] as String? ?? ''),
                    subtitle: Text(
                      contact['owner'] == true
                          ? (l.portalOwner)
                          : (l.portalAdmin),
                    ),
                    trailing:
                        !withdrawn &&
                            contact['available'] == true &&
                            contact['user_id'] is String
                        ? IconButton(
                            key: ValueKey(
                              'public-workspace-chat-${contact['user_id']}',
                            ),
                            tooltip: l.portalChat,
                            icon: const Icon(Icons.chat_outlined),
                            onPressed: preview
                                ? null
                                : () => _chat(context, ref, workspace, contact),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  /// ONE filled action, the inquiry and what asking shares.
  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    PublicWorkspace workspace, {
    required bool withdrawn,
  }) {
    final l = context.l10n;
    return [
      // #1823 — what the space offers: ONE filled action (enter, or ask to
      // join), then #1824's inquiry addressed to the space (read by its host
      // roster, which the sheet shows before anything is written; a space
      // that switched `spaceInquiries` off answers no roster).
      if (!preview && !withdrawn) ...[
        SpaceOffers(
          workspace: workspace,
          onRequest: () => _apply(context, ref, workspace),
          secondary: OutlinedButton.icon(
            key: const ValueKey('write-to-hosts'),
            icon: const Icon(Icons.contact_support_outlined),
            label: Text(l.spaceMessageSpace),
            onPressed: () => _writeToHosts(context, ref, workspace),
          ),
        ),
        Text(
          l.spacePreviewPrivacy,
          key: const ValueKey('public-workspace-privacy'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
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
    final image = Uri.tryParse(workspace.text('image_url'));
    final runBy = switch (workspace.text('host_type')) {
      'association' => l.spaceRunByAssociation,
      'company' => l.spaceRunByCompany,
      _ => l.spaceRunByPerson,
    };
    final page = Scaffold(
      appBar: AppBar(
        // Back and the bookmark; only a preview says what it is.
        title: preview ? Text(l.portalPreview) : null,
        actions: [
          SavedPlaceButton(
            workspace: workspace,
            iconOnly: true,
            enabled: !preview,
            keyPrefix: 'public-workspace-bookmark-',
          ),
        ],
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
                  _InitialBlock(name: workspace.name),
            )
          else
            _InitialBlock(name: workspace.name),
          const SizedBox(height: AppSpacing.sm),
          Text(
            workspace.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (workspace.text('address').isNotEmpty)
            Text(
              workspace.text('address'),
              key: const ValueKey('public-workspace-address'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (workspace.source.isNotEmpty)
            Text(
              serverLabel(l, workspace.source),
              key: const ValueKey('public-workspace-installation'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              runBy,
              key: const ValueKey('public-workspace-run-by'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          WorkspaceFeedback(workspace: workspace, full: true),
          if (withdrawn)
            Padding(
              padding: AppSpacing.smAll,
              child: Text(
                key: const ValueKey('public-workspace-withdrawn'),
                l.portalNoLongerPublished,
              ),
            ),
          ..._details(context, ref, workspace, withdrawn: withdrawn),
          ..._actions(context, ref, workspace, withdrawn: withdrawn),
        ],
      ),
    );
    // Opened from Me, the page wears the personal theme like the rest of Me.
    return personal
        ? Theme(data: personalThemeFrom(Theme.of(context)), child: page)
        : page;
  }
}

/// The place's first letter on a tinted block, when it published no photo.
class _InitialBlock extends StatelessWidget {
  const _InitialBlock({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('public-workspace-initial'),
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.xlAll,
      ),
      child: Text(
        name.characters.firstOrNull?.toUpperCase() ?? '',
        style: Theme.of(context).textTheme.displaySmall
            ?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}

/// Whether a server can be used: not at all, already, or connected now.
enum _Connection { none, already, now }
