// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/personal_home.dart';
import '../../../core/backend/personal_home_providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/loading_view.dart';
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
  const DirectoryScreen({super.key, this.embedded = false});

  final bool embedded;
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
  Future<void> _openMap() async {
    final view = ref.read(discoveryViewProvider.notifier);
    final services = ref.read(mapServicesProvider);
    final current = await ref.read(discoveryViewProvider.future);
    if (!mounted) return;
    if (current.accepts(services.identity)) return view.show(map: true);
    final remembered = ref.read(savedPlacesNamespaceProvider).value != null;
    final accepted = await MapDisclosureDialog.ask(
      context,
      services: services,
      remembered: remembered,
    );
    if (accepted && mounted) await view.acceptMap();
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
        PublicWorkspaceView(workspace: w),
      ),
    );
  }

  Widget _searchField() {
    final l = context.l10n;
    return Padding(
      padding: AppSpacing.mdAll,
      child: TextField(
        key: const ValueKey('directory-portal-search-2'),
        controller: _search,
        decoration: InputDecoration(
          labelText: l.portalSearch,
          suffixIcon: IconButton(
            key: const ValueKey('directory-portal-search'),
            tooltip: l.portalSearch,
            icon: const Icon(Icons.search),
            onPressed: () => _submit(_search.text),
          ),
        ),
        onSubmitted: _submit,
      ),
    );
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
                            '${l.portalDirectoryUnavailable}\n${result.unavailable.join('\n')}',
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
                    child: Text(l.portalNoWorkspaces),
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
    return Center(
      child: TextButton(
        key: const ValueKey('directory-portal-directory-unavailable-2'),
        onPressed: retry,
        child: Text(l.portalDirectoryUnavailable),
      ),
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
            : Text(l.discoveryTitle),
        actions: [
          IconButton(
            key: const ValueKey('directory-portal-list'),
            tooltip: map ? (l.portalList) : (l.portalMap),
            icon: Icon(map ? Icons.list : Icons.map_outlined),
            onPressed: map
                ? () => ref.read(discoveryViewProvider.notifier).show(map: false)
                : _openMap,
          ),
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
