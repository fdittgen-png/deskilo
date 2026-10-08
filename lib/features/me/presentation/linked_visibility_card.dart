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
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../domain/visibility.dart';
import '../providers/me_providers.dart';
import 'visibility_card.dart';
import 'visibility_labels.dart';

/// One row per connected server; nothing when there is none.
class LinkedVisibilityCard extends ConsumerWidget {
  const LinkedVisibilityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(connectedSourcesProvider).value ?? const [];
    if (sources.isEmpty) return const SizedBox.shrink();
    final words = AppLocalizations.of(context) ?? AppLocalizationsEn();
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
                final host = Uri.tryParse(url)?.host ?? url;
                return ListTile(
                  key: ValueKey('linked-visibility-$host'),
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(words.visibilityOnServer(host)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        LinkedVisibilitySheet(source: url, host: host),
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
    required this.host,
  });

  final String source;
  final String host;

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    VisibilityField field,
    FieldAudience current,
  ) async {
    final words = AppLocalizations.of(context) ?? AppLocalizationsEn();
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
    if (picked == null || picked == current.audience || !context.mounted) {
      return;
    }
    final choice = FieldAudience(picked);
    if (choice.widens(current) &&
        !await confirmVisibilityWiden(context, field, choice)) {
      return;
    }
    if (!context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'me',
      message: 'save linked visibility failed',
      errorText: words.visibilitySaveFailed,
      action: () => ref.read(meActionsProvider).chooseOn(source, field, choice),
    );
    if (ok) ref.invalidate(linkedVisibilityProvider(source));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final read = ref.watch(linkedVisibilityProvider(source));
    return SafeArea(
      child: ListView(
        key: const ValueKey('linked-visibility-sheet'),
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              words.visibilityOnServer(host),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (read.hasError)
            InlineBanner(
              key: const ValueKey('linked-visibility-unavailable'),
              icon: Icons.cloud_off_outlined,
              text: words.visibilityOnServerUnavailable(host),
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
                onTap: () => _choose(context, ref, field, visibility.of(field)),
              )
          else
            const LoadingView(),
        ],
      ),
    );
  }
}
