// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3891 — a page that stays the page a person uses while the route above it
// draws nothing (a record open beside its list, list_detail_route.dart).
// The navigator marks a route that is not on top as skipped by Tab
// (`skipTraversal`), so the cycle that comes back from the desk's own
// controls never re-enters the page. While [active], the page's route scope
// is kept in the Tab cycle.
import 'package:flutter/widgets.dart';

/// Keeps the route scope around [child] in the Tab cycle while [active].
class RouteTabReach extends StatefulWidget {
  const RouteTabReach({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  @override
  State<RouteTabReach> createState() => _RouteTabReachState();
}

class _RouteTabReachState extends State<RouteTabReach> {
  FocusScopeNode? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = FocusScope.of(context);
    if (scope == _scope) return;
    _scope?.removeListener(_reach);
    _scope = scope..addListener(_reach);
    _reach();
  }

  // The navigator sets the flag again whenever its route changes; the
  // listener answers each time.
  void _reach() {
    final scope = _scope;
    if (widget.active && scope != null && scope.skipTraversal) {
      scope.skipTraversal = false;
    }
  }

  @override
  void didUpdateWidget(RouteTabReach old) {
    super.didUpdateWidget(old);
    _reach();
  }

  @override
  void dispose() {
    _scope?.removeListener(_reach);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
