// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3629 (desk M10) — the setup guide at the desk. The guide's pages are
// addresses under `/setup` (`levels`, `step/<id>`, `launch`). On the desk
// such an address is an entry in the history that draws nothing
// (`besidePage`): the guide's page stays the one page on screen, the steps
// beside it, and draws the page the address names. So only the navigation
// around a step stays; the step itself is a new page per address, its form,
// draft and timing keyed by account, source, workspace and step
// (SetupStepScreen). The browser's Back and Forward walk the steps opened,
// Ctrl/⌘+Enter opens the next one in the list and Alt+← the one before;
// each way out of a step passes the router's one exit decision (`onExit`).
// Below the desk every address is a page of its own, as before.
//
// Whether the steps are a list or a rail of numbers is decided by the room
// the guide is given, not by the window: the list where a step's form and
// its preview still stand side by side beside it, the rail otherwise.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/list_detail_route.dart';
import '../../../../core/shortcuts/app_shortcuts.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/kit/route_tab_reach.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import '../screens/setup_guide_screen.dart';
import 'setup_steps_pane.dart';

/// The guide's address; its pages are under it.
const String _setupPath = '/setup';

/// Whether the window holds the guide's steps beside its pages: the desk,
/// where the business's navigation stands beside the content.
bool _stepsBeside(BuildContext context) =>
    WindowClass.of(context).atLeast(WindowClass.expanded);

/// The page of an address under the guide: nothing drawn on the desk (the
/// guide draws it beside its steps), else [page] as a page of its own.
Page<void> setupPage(BuildContext context, GoRouterState state, Widget page) =>
    _stepsBeside(context)
    ? besidePage(state)
    : MaterialPage<void>(key: state.pageKey, child: page);

/// The page an address under the guide names: `levels`, `launch` or
/// `step/<id>`; null for any other.
typedef SetupPageFor = Widget? Function(String address);

/// The guide's own page (`/setup`): on the desk, its steps beside the page
/// the address names; elsewhere the guide as before.
class SetupGuidePage extends StatelessWidget {
  const SetupGuidePage({required this.pageFor, super.key});

  final SetupPageFor pageFor;

  @override
  Widget build(BuildContext context) => _stepsBeside(context)
      ? _SetupDesk(pageFor: pageFor)
      : const SetupGuideScreen();
}

/// The address under the guide [path] names (`/setup/step/a` →
/// `step/a`), or null for the guide itself.
String? _addressIn(String path) {
  const prefix = '$_setupPath/';
  if (!path.startsWith(prefix)) return null;
  final rest = path.substring(prefix.length);
  return rest.isEmpty ? null : rest;
}

class _SetupDesk extends ConsumerStatefulWidget {
  const _SetupDesk({required this.pageFor});

  final SetupPageFor pageFor;

  @override
  ConsumerState<_SetupDesk> createState() => _SetupDeskState();
}

class _SetupDeskState extends ConsumerState<_SetupDesk> {
  /// The desk's own place for the keyboard: a page under the guide is an
  /// entry that draws nothing, so no page on top takes the keyboard; the
  /// desk takes it when it is nowhere inside, as a list beside its record
  /// does (ListDetailScaffold).
  final _own = FocusNode(debugLabel: 'setup desk', skipTraversal: true);

  /// The page the keyboard was last offered for: offered once per page
  /// opened, never while a dialog or another page is on top.
  Object? _keysFor = const Object();

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  void _takeKeys() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final now = FocusManager.instance.primaryFocus;
    final inside = now != null && (now == _own || now.ancestors.contains(_own));
    if (mounted && !inside) _own.requestFocus();
  });

  @override
  Widget build(BuildContext context) {
    // The router's own configuration, not the reported address: a way out
    // a step refused (`onExit`) leaves the configuration where it was.
    final delegate = GoRouter.of(context).routerDelegate;
    return ListenableBuilder(
      listenable: delegate,
      builder: (context, _) {
        final path = delegate.currentConfiguration.uri.path;
        final open = _addressIn(path);
        final page = open == null ? null : widget.pageFor(open);
        final shown = path == _setupPath || open != null;
        if (shown && open != _keysFor) {
          _keysFor = open;
          _takeKeys();
        }
        return LayoutBuilder(
          builder: (context, box) {
            // content-fit: the list where a step's form and its preview
            // still stand side by side beside it (SetupStepLayout); the
            // rail of numbers otherwise.
            final list =
                box.maxWidth >=
                SetupStepsPane.listWidth + WindowClass.expandedMinWidth;
            // The keys work wherever the focus is on the desk: in the
            // steps beside the page or in the page itself.
            // The page's route is under an entry that draws nothing: it
            // stays in the Tab cycle while a page under the guide is shown.
            return RouteTabReach(
              active: shown && open != null,
              child: Focus(
                focusNode: _own,
                child: CallbackShortcuts(
                  bindings: shortcutBindings({
                    AppShortcutId.submit: () => _step(context, ref, open, 1),
                    AppShortcutId.previousStep: () =>
                        _step(context, ref, open, -1),
                  }),
                  // The steps, then the page: stated, so a list scrolled by
                  // Tab keeps its place in the cycle (#3891).
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(1),
                          child: FocusTraversalGroup(
                            child: SizedBox(
                              width: list
                                  ? SetupStepsPane.listWidth
                                  : SetupStepsPane.railWidth,
                              child: SetupStepsPane(
                                open: page == null ? null : open,
                                rail: !list,
                                onOpen: (to) => _go(context, to),
                              ),
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: FocusTraversalOrder(
                            order: const NumericFocusOrder(2),
                            child: FocusTraversalGroup(
                              child: KeyedSubtree(
                                key: ValueKey('setup-desk-page|${open ?? ''}'),
                                child: BesidePageTitle(
                                  shown: shown && page != null,
                                  child:
                                      page ??
                                      const SetupGuideScreen(listBeside: true),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Goes to [to] under the guide (null: the guide): an entry in the
  /// history, so the browser's Back returns.
  void _go(BuildContext context, String? to) =>
      context.go(to == null ? _setupPath : '$_setupPath/$to');

  /// The page [by] places after (1) or before (-1) [open] in the steps'
  /// order; nothing past either end.
  void _step(BuildContext context, WidgetRef ref, String? open, int by) {
    final workspaceId = ref.read(currentWorkspaceProvider).value?.id;
    if (workspaceId == null) return;
    final status = ref.read(workspaceSetupStatusProvider(workspaceId)).value;
    if (status == null) return;
    final order = setupDeskSequence(status);
    final at = open == null ? -1 : order.indexOf(open);
    final to = at + by;
    if (to < 0 || to >= order.length) return;
    _go(context, order[to]);
  }
}
