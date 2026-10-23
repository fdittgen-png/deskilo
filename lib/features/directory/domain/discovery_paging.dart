// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The discovery list, page by page and source by source.
//
// Each source installation keeps its own pages: "Show more" asks that
// source alone for its next page, and a page that fails leaves the pages
// already loaded in place and the source at the same page, so a retry
// asks for exactly the page that failed. Pages of two sources are never
// merged into one numbering, so one source moving on never skips or
// repeats another's cards. The directory's own list of sources pages the
// same way: more directories append new sources and keep every source
// already listed as it stands.
import 'public_workspace.dart';

/// One source installation of public cards: its origin and the
/// publishable key its anonymous reads carry.
class DirectorySource {
  const DirectorySource(this.origin, this.key);
  final String origin, key;

  @override
  bool operator ==(Object other) =>
      other is DirectorySource && other.origin == origin && other.key == key;

  @override
  int get hashCode => Object.hash(origin, key);
}

/// One page of the directory's list of sources.
class DirectorySourcesPage {
  const DirectorySourcesPage(
    this.sources, {
    this.refused = const [],
    required this.more,
  });

  /// The sources this page names that may be asked for cards, in the
  /// directory's order.
  final List<DirectorySource> sources;

  /// Sources the page named that are never contacted: a row this version
  /// cannot read, or an endpoint that is not a valid public one.
  final List<String> refused;

  /// A full page: the directory may list more. Never a total.
  final bool more;
}

/// One page of one source's cards.
class SourceCardsPage {
  const SourceCardsPage(
    this.cards, {
    this.incompatible = false,
    required this.more,
  });
  final List<PublicWorkspace> cards;

  /// The source answered with a card this version cannot honour; its
  /// other cards are in [cards].
  final bool incompatible;

  /// A full page: the source may have more. Never a total.
  final bool more;
}

enum SourceStatus { loading, ready, failed }

/// What discovery holds of one source: every page loaded so far, in order.
class SourceListing {
  const SourceListing(
    this.source, {
    this.cards = const [],
    this.pages = 0,
    this.more = false,
    this.incompatible = false,
    this.status = SourceStatus.loading,
  });
  final DirectorySource source;
  final List<PublicWorkspace> cards;

  /// How many pages arrived; the next page asked is this one.
  final int pages;
  final bool more, incompatible;
  final SourceStatus status;

  String get origin => source.origin;

  /// Whether this source can be asked for its next page now: it said it
  /// may have more, or its last request failed and the same page is
  /// asked again.
  bool get canAdvance =>
      status == SourceStatus.failed || (status == SourceStatus.ready && more);

  SourceListing _copy({
    List<PublicWorkspace>? cards,
    int? pages,
    bool? more,
    bool? incompatible,
    required SourceStatus status,
  }) => SourceListing(
    source,
    cards: cards ?? this.cards,
    pages: pages ?? this.pages,
    more: more ?? this.more,
    incompatible: incompatible ?? this.incompatible,
    status: status,
  );

  SourceListing loading() => _copy(status: SourceStatus.loading);

  /// [page] arrived: its cards follow the ones already here, a card
  /// already held is not repeated, and the source moves to the next page.
  SourceListing loaded(SourceCardsPage page) {
    final held = {for (final c in cards) c.id};
    return _copy(
      cards: [
        ...cards,
        for (final c in page.cards)
          if (held.add(c.id)) c,
      ],
      pages: pages + 1,
      more: page.more,
      incompatible: incompatible || page.incompatible,
      status: SourceStatus.ready,
    );
  }

  /// The request failed: the loaded pages stay and the page stays the
  /// same, so a retry asks for exactly the one that failed.
  SourceListing failed() => _copy(status: SourceStatus.failed);
}

/// Everything discovery has loaded for one query.
class DiscoveryResults {
  const DiscoveryResults({
    this.sources = const [],
    this.refused = const [],
    this.sourcePages = 0,
    this.moreSources = false,
    this.sourcesFailed = false,
    this.sourcesLoading = false,
  });
  final List<SourceListing> sources;

  /// Sources a directory page named and that are never contacted.
  final List<String> refused;

  /// How many pages of the directory's source list arrived.
  final int sourcePages;
  final bool moreSources, sourcesFailed, sourcesLoading;

  /// [page] of the source list arrived: its sources join after the ones
  /// already listed, each starting at its first page; a source already
  /// listed keeps its state.
  DiscoveryResults withSources(DirectorySourcesPage page) {
    final known = {for (final s in sources) s.origin};
    return DiscoveryResults(
      sources: [
        ...sources,
        for (final s in page.sources)
          if (known.add(s.origin)) SourceListing(s),
      ],
      refused: [...refused, ...page.refused],
      sourcePages: sourcePages + 1,
      moreSources: page.more,
    );
  }

  DiscoveryResults _sourcesState({
    required bool failed,
    required bool loading,
  }) => DiscoveryResults(
    sources: sources,
    refused: refused,
    sourcePages: sourcePages,
    moreSources: moreSources,
    sourcesFailed: failed,
    sourcesLoading: loading,
  );

  DiscoveryResults sourcesRequested() =>
      _sourcesState(failed: false, loading: true);

  /// The next source page failed: the sources listed stay as they are.
  DiscoveryResults sourcesFailedToLoad() =>
      _sourcesState(failed: true, loading: false);

  /// Whether the directory's next source page can be asked now.
  bool get canAddSources => !sourcesLoading && (moreSources || sourcesFailed);

  /// Replaces the listing of [origin] with what [change] makes of it.
  DiscoveryResults updating(
    String origin,
    SourceListing Function(SourceListing) change,
  ) => DiscoveryResults(
    sources: [
      for (final s in sources)
        if (s.origin == origin) change(s) else s,
    ],
    refused: refused,
    sourcePages: sourcePages,
    moreSources: moreSources,
    sourcesFailed: sourcesFailed,
    sourcesLoading: sourcesLoading,
  );

  SourceListing? of(String origin) =>
      sources.where((s) => s.origin == origin).firstOrNull;

  /// Every loaded card, source by source, each source+id once.
  List<PublicWorkspace> get workspaces {
    final seen = <String>{};
    return [
      for (final s in sources)
        for (final c in s.cards)
          if (seen.add('${c.source}/${c.id}')) c,
    ];
  }

  /// Sources whose cards are missing or incomplete because they could not
  /// be read: refused ones, and ones whose last request failed.
  List<String> get unavailable => [
    ...refused,
    for (final s in sources)
      if (s.status == SourceStatus.failed) s.origin,
  ];

  List<String> get incompatible => [
    for (final s in sources)
      if (s.incompatible) s.origin,
  ];

  /// How many sources answered at least one page.
  int get answered => sources.where((s) => s.pages > 0).length;
}

/// The PUBLIC discovery interface: anonymous reads of deliberately
/// published cards, on the directory and every source it lists. It holds
/// no session and offers no write.
abstract interface class PublicDiscoveryRepository {
  /// Page [page] of the directory's sources. The first page also names the
  /// directory itself and this device's own server when it is another.
  Future<DirectorySourcesPage> sources({int page = 0});

  /// Page [page] of [source]'s cards matching [query]; throws when the
  /// source cannot be read.
  Future<SourceCardsPage> workspaces(
    DirectorySource source,
    String query, {
    int page = 0,
  });

  /// The card as its installation publishes it NOW; null when it is no
  /// longer published.
  Future<PublicWorkspace?> detail(PublicWorkspace card);
}
