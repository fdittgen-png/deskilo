// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2211 (4) — who sees me on my other servers.
//
// A connected installation is the app signed in to another server with
// that server's own account; nothing federates. What people there see of
// me is what that account allows, so it is set THERE, through the same
// my_visibility / set_visibility calls the home card uses, with the same
// caps (contact details and presence never leave my spaces). Chosen
// spaces are not offered: the spaces to choose from live on that server.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../core/ui/server_label.dart';
import '../domain/visibility.dart';
import '../providers/me_providers.dart';
import 'visibility_flow.dart';
import 'visibility_labels.dart';

/// One row per connected server; nothing when there is none.
class LinkedVisibilityCard extends ConsumerWidget {
  const LinkedVisibilityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(connectedSourcesProvider).value ?? const [];
    if (sources.isEmpty) return const SizedBox.shrink();
    final words = context.l10n;
    return Card(
      key: const ValueKey('me-linked-visibility-card'),
      margin: AppSpacing.gutterAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(
              words.visibilityElsewhereTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(words.visibilityElsewhereIntro),
          ),
          for (final source in sources)
            Builder(
              builder: (context) {
                final url = source.endpoint.url;
                final label = serverLabel(words, url);
                return ListTile(
                  key: ValueKey('linked-visibility-${source.endpoint.host}'),
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(words.visibilityOnServer(label)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showAppSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        LinkedVisibilitySheet(source: url, label: label),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The fields of my account on one linked server, each with its audience.
class LinkedVisibilitySheet extends ConsumerWidget {
  const LinkedVisibilitySheet({
    super.key,
    required this.source,
    required this.label,
  });

  final String source;

  /// How the server is named to the person ([serverLabel]).
  final String label;

  /// The audiences this field may have on another server: chosen spaces
  /// are not offered, the spaces to choose from live there.
  Future<FieldAudience?> _pick(
    BuildContext context,
    VisibilityField field,
    FieldAudience current,
  ) async {
    final words = context.l10n;
    final picked = await showDialog<VisibilityAudience>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(visibilityFieldLabel(words, field)),
        children: [
          for (final audience in field.allowedAudiences)
            if (audience != VisibilityAudience.chosenSpaces)
              ListTile(
                key: ValueKey('linked-visibility-audience-${audience.wire}'),
                leading: Icon(
                  audience == current.audience
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(audienceLabel(words, audience)),
                onTap: () => Navigator.of(dialog).pop(audience),
              ),
        ],
      ),
    );
    return picked == null ? null : FieldAudience(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = context.l10n;
    final read = ref.watch(linkedVisibilityProvider(source));
    return SafeArea(
      child: ListView(
        key: const ValueKey('linked-visibility-sheet'),
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              words.visibilityOnServer(label),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (read.hasError)
            InlineBanner(
              key: const ValueKey('linked-visibility-unavailable'),
              icon: Icons.cloud_off_outlined,
              text: words.visibilityOnServerUnavailable(label),
              actionLabel: words.commonRetry,
              onAction: () => ref.invalidate(linkedVisibilityProvider(source)),
            )
          else if (read.value case final visibility?)
            for (final field in [
              ...VisibilityField.seen,
              VisibilityField.reachability,
            ])
              ListTile(
                key: ValueKey('linked-visibility-field-${field.wire}'),
                leading: Icon(visibilityFieldIcon(field)),
                title: Text(visibilityFieldLabel(words, field)),
                subtitle: Text(audienceSummary(words, visibility.of(field))),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => chooseAudience(
                  context,
                  field: field,
                  current: visibility.of(field),
                  pick: () => _pick(context, field, visibility.of(field)),
                  save: (choice) => ref
                      .read(meActionsProvider)
                      .chooseOn(source, field, choice),
                  reread: () =>
                      ref.invalidate(linkedVisibilityProvider(source)),
                ),
              )
          else
            const LoadingView(),
        ],
      ),
    );
  }
}
