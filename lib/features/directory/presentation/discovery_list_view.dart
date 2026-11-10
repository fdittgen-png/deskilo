// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/motion.dart';
import '../../../core/ui/personal_kit/me_notice.dart';
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
/// Beside the map ([revealSelected]), a place selected there is scrolled
/// into view here, so both panes show the same selection.
class DiscoveryListView extends ConsumerStatefulWidget {
  const DiscoveryListView({
    super.key,
    required this.query,
    required this.results,
    required this.selected,
    required this.onView,
    required this.onLocate,
    required this.onClear,
    this.revealSelected = false,
  });

  final String query;
  final DiscoveryResults results;
  final PublicWorkspace? selected;
  final ValueChanged<PublicWorkspace> onView, onLocate;

  /// Empties the search: the way out of a query with no result.
  final VoidCallback onClear;
  final bool revealSelected;

  @override
  ConsumerState<DiscoveryListView> createState() => _DiscoveryListState();
}

class _DiscoveryListState extends ConsumerState<DiscoveryListView> {
  final _scroll = ScrollController();

  /// The counts and the names of silent directories, shown on request.
  var _details = false;
  final _selectedRow = GlobalKey(debugLabel: 'discovery-selected-row');

  /// Jumps toward a card not built yet before giving up on revealing it.
  static const _approaches = 2;

  /// Where the selected card sits among the cards shown, as of the last
  /// build: how a card the list has not built yet is approached.
  var _selectedAt = -1, _shownRows = 0;

  String get query => widget.query;
  DiscoveryResults get results => widget.results;

  static bool _same(PublicWorkspace? a, PublicWorkspace? b) =>
      a?.id == b?.id && a?.source == b?.source;

  @override
  void didUpdateWidget(DiscoveryListView old) {
    super.didUpdateWidget(old);
    if (widget.revealSelected &&
        widget.selected != null &&
        !_same(widget.selected, old.selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(_approaches));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the selected card into view. A card not built yet is first
  /// approached by its position among the shown cards, then revealed.
  void _reveal(int tries) {
    if (!mounted) return;
    final row = _selectedRow.currentContext;
    if (row != null) {
      if (_inView(row)) return;
      // A card reached by a jump is placed at once: the list's estimate
      // of the cards above it is still settling.
      unawaited(Scrollable.ensureVisible(
        row,
        alignment: 0.1,
        duration: tries == _approaches
            ? AppMotion.viewSwitchOf(context)
            : Duration.zero,
      ));
      return;
    }
    if (tries == 0 || _selectedAt < 0 || !_scroll.hasClients) return;
    final position = _scroll.position;
    _scroll.jumpTo(position.maxScrollExtent * _selectedAt / _shownRows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(tries - 1));
  }

  /// Whether [row] is wholly inside the list's viewport: a card chosen
  /// where it already shows is not moved under the person's eyes.
  static bool _inView(BuildContext row) {
    final card = row.findRenderObject();
    final list = Scrollable.of(row).context.findRenderObject();
    if (card is! RenderBox || list is! RenderBox) return false;
    final viewport = list.localToGlobal(Offset.zero) & list.size;
    final rect = card.localToGlobal(Offset.zero) & card.size;
    return rect.top >= viewport.top && rect.bottom <= viewport.bottom;
  }

  Widget _row(PublicWorkspace w) {
    final selected = _same(widget.selected, w);
    final row = DirectoryRow(
      workspace: w,
      selected: selected,
      onView: () => widget.onView(w),
      onLocate: () => widget.onLocate(w),
    );
    return selected ? KeyedSubtree(key: _selectedRow, child: row) : row;
  }

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

  /// What an empty list says: no saved place, what to type before a search,
  /// or what was typed and the way to start over.
  List<Widget> _emptyState(bool savedOnly) {
    final l = context.l10n;
    if (savedOnly) {
      return [
        EmptyState(
          key: const ValueKey('directory-empty-saved'),
          icon: Icons.bookmark_border,
          title: l.discoveryNoSaved,
        ),
      ];
    }
    if (query.trim().isEmpty) {
      return [
        EmptyState(
          key: const ValueKey('directory-start'),
          icon: Icons.travel_explore_outlined,
          title: l.discoveryStartTitle,
          subtitle: l.discoveryStartBody,
        ),
      ];
    }
    return [
      EmptyState(
        key: const ValueKey('directory-no-match'),
        icon: Icons.search_off_outlined,
        title: l.discoveryNoMatchTitle(query.trim()),
      ),
      Center(
        child: OutlinedButton(
          key: const ValueKey('directory-clear-search'),
          onPressed: widget.onClear,
          child: Text(l.discoveryClearSearch),
        ),
      ),
    ];
  }

  /// A directory that did not answer is one line with its Retry beside the
  /// results that loaded -- never instead of them; the counts and the names
  /// are for whoever asks: behind Details.
  List<Widget> _notices() {
    final l = context.l10n;
    final refused = results.refused;
    return [
      if (refused.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: MeNotice(
            key: const ValueKey('directory-portal-directory-unavailable'),
            text: l.discoveryDirectoriesDidNotAnswer(refused.length),
            retryLabel: l.commonRetry,
            onRetry: () => ref.invalidate(discoveryListingProvider(query)),
          ),
        ),
    ];
  }

  /// Details, at the END of the list: the counts and the names of the
  /// directories that did not answer, for whoever asks.
  List<Widget> _detailsAtEnd(int loaded, int shown) {
    final l = context.l10n;
    final refused = results.refused;
    return [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: const ValueKey('directory-details'),
          onPressed: () => setState(() => _details = !_details),
          icon: Icon(_details ? Icons.expand_less : Icons.expand_more),
          label: Text(
            l.bookingOpenDetails,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
      if (_details) ...[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            key: const ValueKey('directory-loaded-count'),
            l.discoveryLoadedCount(
              loaded,
              shown,
              results.answered,
              results.sources.length,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (refused.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              refused.join('\n'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
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
    final order = <String>{
      for (final s in results.sources)
        for (final w in s.cards)
          if (shows(w)) '${w.source}/${w.id}',
    }.toList();
    _shownRows = order.length;
    _selectedAt = widget.selected == null
        ? -1
        : order.indexOf('${widget.selected!.source}/${widget.selected!.id}');
    return ListView(
      controller: _scroll,
      padding: AppSpacing.mdAll,
      children: [
        ..._notices(),
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
        if (shown == 0) ..._emptyState(savedOnly),
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
        ..._detailsAtEnd(loaded.length, shown),
      ],
    );
  }
}
