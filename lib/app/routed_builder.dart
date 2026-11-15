// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4057 — a builder that follows the router. The router's delegate announces
// a pop while the navigator is building, where a `ListenableBuilder` may not
// be marked dirty: a notice that arrives mid-build is taken after the frame.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

/// What a window drawn around the pages follows: the router's information
/// and its delegate. An imperative pop (the in-app Back from a pushed page)
/// tells the delegate, not the information provider, so the window keeps the
/// chrome of the page that was left unless both are heard.
Listenable routeChanges(GoRouter router) =>
    Listenable.merge([router.routeInformationProvider, router.routerDelegate]);

/// Builds with [builder] and again whenever [listenable] changes, taking a
/// change announced during a build after that frame.
class RoutedBuilder extends StatefulWidget {
  const RoutedBuilder({
    required this.listenable,
    required this.builder,
    super.key,
  });

  final Listenable listenable;
  final WidgetBuilder builder;

  @override
  State<RoutedBuilder> createState() => _RoutedBuilderState();
}

class _RoutedBuilderState extends State<RoutedBuilder> {
  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_changed);
  }

  @override
  void didUpdateWidget(RoutedBuilder old) {
    super.didUpdateWidget(old);
    if (old.listenable == widget.listenable) return;
    old.listenable.removeListener(_changed);
    widget.listenable.addListener(_changed);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
