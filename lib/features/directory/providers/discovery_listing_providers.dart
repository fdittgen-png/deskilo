// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/discovery_paging.dart';
import 'directory_providers.dart';

part 'discovery_listing_providers.g.dart';

Duration? _noRetry(int count, Object error) => null;

/// What discovery has loaded for [query]: the directory's first page of
/// sources and the first page of each, then whatever the person asks for
/// more of. A new query is a new listing; an answer that arrives after its
/// listing was left is dropped, so it never replaces a newer one.
@Riverpod(retry: _noRetry)
class DiscoveryListing extends _$DiscoveryListing {
  @override
  Future<DiscoveryResults> build(String query) async {
    final repository = ref.watch(publicDiscoveryRepositoryProvider);
    final first = await repository.sources();
    var results = const DiscoveryResults().withSources(first);
    final pages = await Future.wait([
      for (final s in results.sources) _page(s),
    ]);
    for (final (index, page) in pages.indexed) {
      results = results.updating(results.sources[index].origin, (_) => page);
    }
    return results;
  }

  /// Reads [listing]'s next page; never throws: a failure is the listing
  /// marked failed, with every page it had.
  Future<SourceListing> _page(SourceListing listing) async {
    try {
      final page = await ref
          .read(publicDiscoveryRepositoryProvider)
          .workspaces(listing.source, query, page: listing.pages);
      return listing.loaded(page);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'directory',
        'a public source page could not be read',
        error: e.runtimeType,
        stackTrace: st,
      );
      return listing.failed();
    }
  }

  /// Asks [origin] alone for its next page, or again for the page that
  /// failed. Every other source stays as it is.
  Future<void> more(String origin) async {
    final current = state.value?.of(origin);
    if (current == null || !current.canAdvance) return;
    state = AsyncData(state.value!.updating(origin, (s) => s.loading()));
    final next = await _page(current);
    if (!ref.mounted) return;
    state = AsyncData(state.value!.updating(origin, (_) => next));
  }

  /// Asks the directory for its next page of sources (or again for the one
  /// that failed) and reads the first page of each new source. The sources
  /// already listed keep every page they have.
  Future<void> moreSources() async {
    final current = state.value;
    if (current == null || !current.canAddSources) return;
    state = AsyncData(current.sourcesRequested());
    final DirectorySourcesPage page;
    try {
      page = await ref
          .read(publicDiscoveryRepositoryProvider)
          .sources(page: current.sourcePages);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'directory',
        'the next page of public sources could not be read',
        error: e.runtimeType,
        stackTrace: st,
      );
      if (ref.mounted) state = AsyncData(state.value!.sourcesFailedToLoad());
      return;
    }
    if (!ref.mounted) return;
    final known = {for (final s in state.value!.sources) s.origin};
    state = AsyncData(state.value!.withSources(page));
    final added = [
      for (final s in state.value!.sources)
        if (!known.contains(s.origin)) s,
    ];
    final loaded = await Future.wait([for (final s in added) _page(s)]);
    if (!ref.mounted) return;
    var results = state.value!;
    for (final listing in loaded) {
      results = results.updating(listing.origin, (_) => listing);
    }
    state = AsyncData(results);
  }
}
