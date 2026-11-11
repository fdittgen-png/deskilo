// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/personal_home.dart';
import '../../../core/backend/personal_home_providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/loading_view.dart';
import '../../../core/ui/personal_kit/me_filled_field.dart';
import '../../../core/ui/personal_kit/me_notice.dart';
import '../../../core/ui/view_toggle.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/discovery_paging.dart';
import '../domain/public_workspace.dart';
import '../providers/discovery_listing_providers.dart';
import '../providers/discovery_view_providers.dart';
import '../providers/saved_places_providers.dart';
import 'directory_carousel.dart';
import 'directory_link_dialog.dart';
import 'directory_map.dart';
import 'directory_pages.dart';
import 'discovery_list_view.dart';
import 'discovery_split.dart';
import 'map_disclosure_dialog.dart';
import 'public_workspace_view.dart';

class DirectoryScreen extends ConsumerStatefulWidget {
  const DirectoryScreen({
    super.key,
    this.embedded = false,
    this.focusSearch = false,
  });

  final bool embedded;

  /// The search box takes focus when the screen opens (#3545: Home sends a
  /// person here to type or look, never to an empty list).
  final bool focusSearch;
  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryState();
}

class _DirectoryState extends ConsumerState<DirectoryScreen> {
  final _search = TextEditingController();
  String _query = '';

  PublicWorkspace? _selected;

  /// One map per listing: it keeps its camera when the window crosses the
  /// split width, and a new search starts a new one.
  var _mapKey = GlobalKey(debugLabel: 'discovery-map');

  /// The list keeps its scroll when the map opens beside it or closes.
  final _listKey = GlobalKey(debugLabel: 'discovery-list');
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DiscoveryListingProvider get _provider => discoveryListingProvider(_query);

  void _select(PublicWorkspace w) => setState(() => _selected = w);

  /// The list is the first face; the map is a disclosure behind the
  /// toggle. Before it first loads from a provider, the person is told who
  /// that provider is and what it receives, and nothing loads unless they
  /// choose the map.
  ///
  /// #3684 -- a map that cannot be opened says so: a failure on the way,
  /// or a provider no longer accepted, ends in a message, never in nothing.
  Future<void> _openMap() async {
    try {
      final view = ref.read(discoveryViewProvider.notifier);
      final services = ref.read(mapServicesProvider);
      final current = await ref.read(discoveryViewProvider.future);
      if (!mounted) return;
      if (current.accepts(services.identity)) {
        if (!await view.show(map: true)) _mapUnavailable();
        return;
      }
      final remembered = ref.read(savedPlacesNamespaceProvider).value != null;
      final accepted = await MapDisclosureDialog.ask(
        context,
        services: services,
        remembered: remembered,
      );
      if (accepted && mounted) await view.acceptMap();
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'directory',
        'the map could not be opened',
        error: e.runtimeType,
        stackTrace: st,
      );
      _mapUnavailable();
    }
  }

  void _mapUnavailable() {
    if (!mounted) return;
    AppSnack.error(context, context.l10n.directoryMapOpenFailed);
  }

  /// The labelled List | Map switch: the map side asks first, as the
  /// card's Locate does.
  Widget _viewSwitch(bool map) {
    final l = context.l10n;
    return Padding(
      padding: AppSpacing.smH,
      child: ViewToggle<bool>(
        key: const ValueKey('directory-view-switch'),
        selected: map,
        onChanged: (toMap) => unawaited(
          toMap
              ? _openMap()
              : ref.read(discoveryViewProvider.notifier).show(map: false),
        ),
        options: [
          ViewToggleOption(value: false, icon: Icons.list, label: l.portalList),
          ViewToggleOption(
            value: true,
            icon: Icons.map_outlined,
            label: l.portalMap,
          ),
        ],
      ),
    );
  }

  void _locate(PublicWorkspace w) {
    _select(w);
    unawaited(_openMap());
  }

  void _open(PublicWorkspace w) {
    _select(w);
    unawaited(
      publicWorkspacePage.open<void>(
        context,
        PublicWorkspaceView(workspace: w, personal: widget.embedded),
      ),
    );
  }

  Widget _searchField() {
    final l = context.l10n;
    return Padding(
      padding: AppSpacing.mdAll,
      child: MeFilledField(
        child: TextField(
          key: const ValueKey('directory-portal-search-2'),
          controller: _search,
          autofocus: widget.focusSearch,
          decoration: InputDecoration(
            hintText: l.meFindPlaceHint,
            suffixIcon: IconButton(
              key: const ValueKey('directory-portal-search'),
              tooltip: l.portalSearch,
              icon: const Icon(Icons.search),
              onPressed: () => _submit(_search.text),
            ),
          ),
          onSubmitted: _submit,
        ),
      ),
    );
  }

  /// The search emptied: the start of Discover again.
  void _clear() {
    _search.clear();
    _submit('');
  }

  /// A new search is a new listing: every source starts again at its
  /// first page, and the old listing's late answers are dropped.
  void _submit(String value) => setState(() {
    _query = value;
    _selected = null;
    _mapKey = GlobalKey(debugLabel: 'discovery-map');
  });

  Widget _map(DiscoveryResults result) => DirectoryMap(
    key: _mapKey,
    workspaces: result.workspaces,
    selected: _selected == null
        ? null
        : '${_selected!.source}/${_selected!.id}',
    onSelect: _select,
  );

  Widget _list(DiscoveryResults result, {required bool beside}) =>
      DiscoveryListView(
        key: _listKey,
        query: _query,
        results: result,
        selected: _selected,
        onView: _open,
        onLocate: _locate,
        onClear: _clear,
        revealSelected: beside,
      );

  /// Wide enough for both: the whole loaded list beside the map, 53:47.
  /// A place selected in either pane is the selection of both.
  Widget _split(DiscoveryResults result) => Row(
    key: const ValueKey('directory-split'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        flex: DiscoverySplit.listFlex,
        child: _list(result, beside: true),
      ),
      const VerticalDivider(width: 1),
      Expanded(flex: DiscoverySplit.mapFlex, child: _map(result)),
    ],
  );

  /// The map alone, on a screen too narrow for the split: the workspaces
  /// are cards to swipe through under it. The pin and the card in front
  /// are the same selection.
  Widget _mapView(DiscoveryResults result) {
    final l = context.l10n;
    return Stack(children: [
      Positioned.fill(child: _map(result)),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (result.unavailable.isNotEmpty || result.incompatible.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Material(
                  elevation: 2,
                  borderRadius: AppRadius.mdAll,
                  child: Padding(
                    padding: AppSpacing.smAll,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (result.unavailable.isNotEmpty)
                          Text(
                            '${l.discoveryDirectoriesDidNotAnswer(result.unavailable.length)}\n${result.unavailable.join('\n')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (result.incompatible.isNotEmpty)
                          Text(
                            key: const ValueKey('directory-incompatible'),
                            '${l.portalDirectoryIncompatible}\n${result.incompatible.join('\n')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (result.workspaces.isEmpty)
              Padding(
                padding: AppSpacing.mdAll,
                child: Material(
                  elevation: 2,
                  borderRadius: AppRadius.lgAll,
                  child: Padding(
                    padding: AppSpacing.mdAll,
                    child: Text(l.discoveryStartTitle),
                  ),
                ),
              )
            else
              DirectoryCarousel(
                workspaces: result.workspaces,
                selected: _selected,
                onSelect: _select,
                onOpen: _open,
              ),
          ]),
        ),
      ),
    ]);
  }

  /// The directory could not be listed. A server that names no usable
  /// personal home says so (#2555): no other server is asked instead. A
  /// retry reads the declaration again, so a corrected one is seen.
  Widget _failure(Object error) {
    final l = context.l10n;
    void retry() => ref
      ..invalidate(directoryHomeProvider)
      ..invalidate(_provider);
    if (error is PersonalHomeUnavailable) {
      return Center(
        child: Padding(
          padding: AppSpacing.mdAll,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              l.directoryHomeUnavailable,
              key: const ValueKey('directory-home-unavailable'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const ValueKey('directory-home-retry'),
              onPressed: retry,
              child: Text(l.commonRetry),
            ),
          ]),
        ),
      );
    }
    // A listing that could not be read is one line with its Retry above
    // the start state, never a centred message on a blank page.
    return Column(
      children: [
        Padding(
          padding: AppSpacing.mdAll,
          child: MeNotice(
            key: const ValueKey('directory-portal-directory-unavailable-2'),
            text: l.discoveryDirectoriesDidNotAnswer(1),
            retryLabel: l.commonRetry,
            onRetry: retry,
          ),
        ),
        EmptyState(
          icon: Icons.travel_explore_outlined,
          title: l.discoveryStartTitle,
          subtitle: l.discoveryStartBody,
        ),
      ],
    );
  }

  /// The list alone; or, with the map chosen, the split where it fits and
  /// otherwise the map alone. The search stays above either, never over
  /// the map's own controls.
  Widget _body(
    AsyncValue<DiscoveryResults> rows,
    Widget searchField, {
    required bool map,
    required bool split,
  }) => Column(children: [
    searchField,
    Expanded(
      child: switch (rows) {
        AsyncData(value: final result) => split
            ? _split(result)
            : map
                ? _mapView(result)
                : _list(result, beside: false),
        AsyncError(:final error) => _failure(error),
        _ => const LoadingView(),
      },
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = ref.watch(_provider);
    final services = ref.watch(mapServicesProvider);
    final map = ref.watch(discoveryViewProvider).value?.opensMap(
          services.identity,
        ) ??
        false;
    final searchField = _searchField();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: widget.embedded
            ? null
            : Text(l.meTabDiscover),
        actions: [
          _viewSwitch(map),
          if (ref.watch(authStateProvider).value != null)
            IconButton(
              key: const ValueKey('directory-portal-register-directory'),
              tooltip:
                  l.portalRegisterDirectory,
              icon: const Icon(Icons.add_business_outlined),
              // #2343 — opens on this device's own server: the one an
              // operator most often wants listed. #2555 — as the personal
              // client names it, never the selected workspace's host.
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => DirectoryLinkDialog(
                  initial: ref.read(personalEndpointProvider),
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => _body(
          rows,
          searchField,
          map: map,
          split: map && DiscoverySplit.fits(constraints.maxWidth),
        ),
      ),
    );
  }
}
