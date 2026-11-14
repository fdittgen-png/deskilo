// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3607 (desk K2) — the address of an open record, `/<list>/:id`, as a child
// of its list's route. On a large window the child is an entry in the
// history that draws nothing: the list's page stays the one page on
// screen and draws the record in its pane (ListDetailScaffold), so the
// browser's Back closes the pane and the list keeps its state. Below large
// the child is the record as a page of its own over the list.
//
// Opening a record from the list pushes its address once; moving to the
// next record with the arrow keys replaces it, so Back never walks through
// every record looked at. Close goes to the list's own address, also after
// a direct link or a reload, where there is no list in the history.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/adaptive/window_class.dart';

/// Whether the window holds a record beside its list: a large window.
bool recordBesideList(BuildContext context) =>
    WindowClass.of(context).index >= WindowClass.large.index;

/// The page of the record [state] names: nothing drawn beside a list on a
/// large window, else [page] as a page of its own.
Page<void> recordPage(
  BuildContext context,
  GoRouterState state,
  Widget Function(String id) page,
) {
  final id = state.pathParameters['id'] ?? '';
  if (recordBesideList(context)) return besidePage(state);
  return MaterialPage<void>(key: state.pageKey, child: page(id));
}

/// #3629 — the entry in the history for [state] that draws nothing: the
/// page under it reads the address and draws what it names.
Page<void> besidePage(GoRouterState state) => _BesidePage(key: state.pageKey);

/// The record [path] names under [listPath] (`/x/a` → `a`), or null.
String? _recordIn(String path, String listPath) {
  final prefix = '$listPath/';
  if (!path.startsWith(prefix)) return null;
  final rest = path.substring(prefix.length);
  if (rest.isEmpty || rest.contains('/')) return null;
  return Uri.decodeComponent(rest);
}

/// Builds with the record open under [listPath], read from the router's
/// address: a push and a replace change the address without rebuilding the
/// list's page, so the page listens to the address itself.
class OpenRecord extends StatelessWidget {
  const OpenRecord({required this.listPath, required this.builder, super.key});

  final String listPath;
  final Widget Function(BuildContext context, String? id) builder;

  @override
  Widget build(BuildContext context) {
    final info = GoRouter.of(context).routeInformationProvider;
    return ListenableBuilder(
      listenable: info,
      builder: (context, _) =>
          builder(context, _recordIn(info.value.uri.path, listPath)),
    );
  }
}

/// Opens [id] beside or over the list at [listPath]: one entry in the
/// history.
void openRecord(BuildContext context, String listPath, String id) =>
    context.push('$listPath/${Uri.encodeComponent(id)}');

/// Shows [id] instead of the record open now (the arrow keys): no new entry.
void moveToRecord(BuildContext context, String listPath, String id) =>
    context.replace('$listPath/${Uri.encodeComponent(id)}');

/// Closes the record: the list's own address.
void closeRecord(BuildContext context, String listPath) => context.go(listPath);

class _BesidePage extends Page<void> {
  const _BesidePage({super.key});

  @override
  Route<void> createRoute(BuildContext context) => _BesideRoute(this);
}

/// An entry in the history with nothing on screen: the list's page under it
/// stays the page a person sees and uses. The navigator asks every route
/// for an overlay entry; this one draws nothing and lets every pointer
/// through.
class _BesideRoute extends Route<void> {
  _BesideRoute(_BesidePage page) : super(settings: page);

  late final List<OverlayEntry> _entries = [
    OverlayEntry(builder: (_) => const IgnorePointer(child: SizedBox.shrink())),
  ];

  @override
  List<OverlayEntry> get overlayEntries => _entries;

  @override
  void dispose() {
    for (final e in _entries) {
      if (e.mounted) e.remove();
      e.dispose();
    }
    super.dispose();
  }
}
