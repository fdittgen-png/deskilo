// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4057 — a builder that follows the router. The router's information provider
// notifies on a navigation, but not on an imperative pop (the in-app Back from
// a pushed page): that reaches the delegate, and while the navigator is
// building. The window drawn around the pages must redraw its chrome for the
// page it came back to, so it also hears the delegate, after the frame, and
// only when the path it drew is no longer the router's.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

/// Builds with [builder], again whenever [router]'s information changes, and
/// again after the frame in which the router's path stopped being the one
/// last built.
class RoutedBuilder extends StatefulWidget {
  const RoutedBuilder({
    required this.router,
    required this.builder,
    super.key,
  });

  final GoRouter router;
  final WidgetBuilder builder;

  @override
  State<RoutedBuilder> createState() => _RoutedBuilderState();
}

class _RoutedBuilderState extends State<RoutedBuilder> {
  String? _built;

  String get _path => widget.router.routeInformationProvider.value.uri.path;

  @override
  void initState() {
    super.initState();
    widget.router.routeInformationProvider.addListener(_informed);
    widget.router.routerDelegate.addListener(_delegated);
  }

  @override
  void didUpdateWidget(RoutedBuilder old) {
    super.didUpdateWidget(old);
    if (old.router == widget.router) return;
    old.router.routeInformationProvider.removeListener(_informed);
    old.router.routerDelegate.removeListener(_delegated);
    widget.router.routeInformationProvider.addListener(_informed);
    widget.router.routerDelegate.addListener(_delegated);
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_informed);
    widget.router.routerDelegate.removeListener(_delegated);
    super.dispose();
  }

  void _informed() {
    if (mounted) setState(() {});
  }

  void _delegated() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _path != _built) setState(() {});
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    _built = _path;
    return widget.builder(context);
  }
}
