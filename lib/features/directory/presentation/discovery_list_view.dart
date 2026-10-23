// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/discovery_paging.dart';
import '../domain/public_workspace.dart';
import '../providers/discovery_listing_providers.dart';
import '../providers/saved_places_providers.dart';
import 'directory_row.dart';

/// The host a source is named by on screen.
String _sourceLabel(String origin) {
  final host = Uri.tryParse(origin)?.host ?? '';
  return host.isEmpty ? origin : host;
}

/// The loaded places, source by source: each source shows its own pages
/// and asks for its own next one, so a source that fails keeps what it
/// showed and offers to try that page again, while the others carry on.
class DiscoveryListView extends ConsumerWidget {
  const DiscoveryListView({
    super.key,
    required this.query,
    required this.results,
    required this.selected,
    required this.onView,
    required this.onLocate,
  });

  final String query;
  final DiscoveryResults results;
  final PublicWorkspace? selected;
  final ValueChanged<PublicWorkspace> onView, onLocate;

  Widget _row(PublicWorkspace w) => DirectoryRow(
    workspace: w,
    selected: selected?.id == w.id && selected?.source == w.source,
    onView: () => onView(w),
    onLocate: () => onLocate(w),
  );

  /// What follows a source's cards: its progress, its failure with a
  /// retry of the same page, or the way to its next page.
  Widget? _footer(BuildContext context, WidgetRef ref, SourceListing s) {
    final l = context.l10n;
    final name = _sourceLabel(s.origin);
    void more() =>
        ref.read(discoveryListingProvider(query).notifier).more(s.origin);
    return switch (s.status) {
      SourceStatus.loading => const Padding(
        padding: AppSpacing.smAll,
        child: LinearProgressIndicator(),
      ),
      SourceStatus.failed => Row(
        children: [
          Expanded(child: Text(l.discoverySourceFailed(name))),
          TextButton(
            key: ValueKey('directory-source-retry-${s.origin}'),
            onPressed: more,
            child: Text(l.commonRetry),
          ),
        ],
      ),
      SourceStatus.ready when s.more => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          key: ValueKey('directory-source-more-${s.origin}'),
          onPressed: more,
          child: Text(l.discoveryShowMoreFrom(name)),
        ),
      ),
      SourceStatus.ready => null,
    };
  }

  Widget? _moreSources(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    void more() =>
        ref.read(discoveryListingProvider(query).notifier).moreSources();
    if (results.sourcesLoading) return const LinearProgressIndicator();
    if (results.sourcesFailed) {
      return Row(
        children: [
          Expanded(child: Text(l.discoveryMoreDirectoriesFailed)),
          TextButton(
            key: const ValueKey('directory-sources-retry'),
            onPressed: more,
            child: Text(l.commonRetry),
          ),
        ],
      );
    }
    if (!results.moreSources) return null;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        key: const ValueKey('directory-portal-more-directories'),
        onPressed: more,
        child: Text(l.portalMoreDirectories),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // Saved places exist only for someone signed in at the personal home;
    // the filter narrows the loaded places to them.
    final canSave = ref.watch(savedPlacesNamespaceProvider).value != null;
    final savedOnly = canSave && ref.watch(discoverSavedOnlyProvider);
    final saved = ref.watch(savedPlacesProvider).value ?? const [];
    bool shows(PublicWorkspace w) =>
        !savedOnly || saved.any((p) => p.matches(w));
    final loaded = results.workspaces;
    final shown = loaded.where(shows).length;
    final held = <String>{};
    final refused = results.refused;
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        Text(
          key: const ValueKey('directory-loaded-count'),
          l.discoveryLoadedCount(
            loaded.length,
            shown,
            results.answered,
            results.sources.length,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (refused.isNotEmpty)
          Text(
            key: const ValueKey('directory-portal-directory-unavailable'),
            '${l.portalDirectoryUnavailable}\n${refused.join('\n')}',
          ),
        // A card this version cannot interpret is not shown; its
        // installation is named, the rest still is.
        if (results.incompatible.isNotEmpty)
          Text(
            key: const ValueKey('directory-incompatible'),
            '${l.portalDirectoryIncompatible}\n'
            '${results.incompatible.join('\n')}',
          ),
        if (canSave)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilterChip(
              key: const ValueKey('directory-saved-filter'),
              label: Text(l.discoverySavedFilter),
              selected: savedOnly,
              onSelected: (_) =>
                  ref.read(discoverSavedOnlyProvider.notifier).toggle(),
            ),
          ),
        if (shown == 0)
          Text(savedOnly ? l.discoveryNoSaved : l.portalNoWorkspaces),
        for (final s in results.sources) ...[
          if (results.sources.length > 1 &&
              (s.cards.any(shows) || s.status != SourceStatus.ready || s.more))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                key: ValueKey('directory-source-${s.origin}'),
                _sourceLabel(s.origin),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          for (final w in s.cards)
            if (shows(w) && held.add('${w.source}/${w.id}')) _row(w),
          ?_footer(context, ref, s),
        ],
        ?_moreSources(context, ref),
      ],
    );
  }
}
