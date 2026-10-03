// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_providers.dart';
import 'connection_dialog.dart';
import 'directory_map.dart';
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
  bool _map = false;
  int _sources = 0, _page = 0;
  PublicWorkspace? _selected;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = publicDirectoryProvider(
      _query,
      sourcePage: _sources,
      workspacePage: _page,
    );
    final rows = ref.watch(provider);
    void select(PublicWorkspace w) => setState(() => _selected = w);
    Widget card(PublicWorkspace w) => Card(
      child: ListTile(
        selected: _selected?.id == w.id && _selected?.source == w.source,
        title: Text(w.name),
        subtitle: Text(w.text('address')),
        trailing: IconButton(
          key: ValueKey('directory-locate-${w.source}/${w.id}'),
          tooltip: l?.directoryLocate ?? 'Locate on map',
          icon: const Icon(Icons.location_on_outlined),
          onPressed: () => setState(() { _selected = w; _map = true; }),
        ),
        onTap: () {
          select(w);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PublicWorkspaceView(workspace: w),
            ),
          );
        },
      ),
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: widget.embedded
            ? null
            : Text(l?.portalDiscover ?? 'Find a workspace'),
        actions: [
          IconButton(
            tooltip: _map ? (l?.portalList ?? 'List') : (l?.portalMap ?? 'Map'),
            icon: Icon(_map ? Icons.list : Icons.map_outlined),
            onPressed: () => setState(() => _map = !_map),
          ),
          if (ref.watch(authStateProvider).value != null)
            IconButton(
              tooltip:
                  l?.portalRegisterDirectory ??
                  'Publish a server in the directory',
              icon: const Icon(Icons.add_business_outlined),
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => const ConnectionDialog(publishDirectory: true),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.mdAll,
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: l?.portalSearch ?? 'Search workspaces',
                suffixIcon: IconButton(
                  tooltip: l?.portalSearch ?? 'Search workspaces',
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() {
                    _query = _search.text;
                    _page = 0;
                    _selected = null;
                  }),
                ),
              ),
              onSubmitted: (value) => setState(() {
                _query = value;
                _page = 0;
                _selected = null;
              }),
            ),
          ),
          Expanded(
            child: switch (rows) {
              AsyncData(value: final result) => LayoutBuilder(
                builder: (context, constraints) => Column(children: [
                  if (_map)
                    SizedBox(
                      height: (constraints.maxHeight / 2).clamp(0.0, 300.0),
                      child: DirectoryMap(
                        key: ValueKey('$_query:$_sources:$_page'),
                        workspaces: result.workspaces,
                        selected: _selected == null
                            ? null
                            : '${_selected!.source}/${_selected!.id}',
                        onSelect: select,
                      ),
                    ),
                  Expanded(child: ListView(
                padding: AppSpacing.mdAll,
                children: [
                  if (result.unavailable.isNotEmpty)
                    TextButton(
                      onPressed: () => ref.invalidate(provider),
                      child: Text(
                        '${l?.portalDirectoryUnavailable ?? 'Some directories could not be reached. Results are incomplete.'}\n${result.unavailable.join('\n')}',
                      ),
                    ),
                  // #1847 — a card this version cannot interpret is not
                  // shown; its installation is named, the rest still is.
                  if (result.incompatible.isNotEmpty)
                    Text(
                      key: const ValueKey('directory-incompatible'),
                      '${l?.portalDirectoryIncompatible ?? 'Some workspaces need a newer version of the app and are not shown.'}\n${result.incompatible.join('\n')}',
                    ),
                  if (result.workspaces.isEmpty)
                    Text(
                      l?.portalNoWorkspaces ?? 'No published workspaces found.',
                    ),
                  for (final w in result.workspaces) card(w),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .previousPageTooltip,
                        onPressed: _page == 0
                            ? null
                            : () => setState(() {
                                _page--;
                                _selected = null;
                              }),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .nextPageTooltip,
                        onPressed: !result.moreWorkspaces
                            ? null
                            : () => setState(() {
                                _page++;
                                _selected = null;
                              }),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Wrap(
                    children: [
                      if (_sources > 0)
                        TextButton(
                          onPressed: () => setState(() {
                            _sources--;
                            _page = 0;
                            _selected = null;
                          }),
                          child: Text(
                            MaterialLocalizations.of(context)
                                .previousPageTooltip,
                          ),
                        ),
                      if (result.moreSources)
                        TextButton(
                          onPressed: () => setState(() {
                            _sources++;
                            _page = 0;
                            _selected = null;
                          }),
                          child: Text(
                            l?.portalMoreDirectories ?? 'More directories',
                          ),
                        ),
                    ],
                  ),
                ],
                  )),
                ]),
              ),
              AsyncError() => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(provider),
                  child: Text(
                    l?.portalDirectoryUnavailable ?? 'Some directories could not be reached. Results are incomplete.',
                  ),
                ),
              ),
              _ => const LoadingView(),
            },
          ),
        ],
      ),
    );
  }
}
