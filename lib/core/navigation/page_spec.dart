// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A full page another screen opens (#2388): a path the router, the route
/// policy and the route registry see, instead of a `Navigator.push` of a
/// `MaterialPageRoute` that has no path at all.
///
/// The page is built from an argument the opener holds ([T]): a pushed
/// page used to receive it as a constructor argument, and a route carries
/// it as `extra`. A link that arrives without it (a reload on the web, a
/// typed address) goes to [fallback] — the screen the page is opened
/// from — rather than building a page with nothing to show.
class PageSpec<T> {
  const PageSpec(
    this.path,
    this.build, {
    required this.fallback,
    this.fullscreenDialog = false,
  });

  /// The page's location, unique among the router's paths.
  final String path;

  /// The page for [T].
  final Widget Function(T argument) build;

  /// Where a link without the argument lands.
  final String fallback;

  /// A full-screen task with a close button instead of a back arrow.
  final bool fullscreenDialog;

  /// The route the router registers for this page.
  GoRoute route() => GoRoute(
    path: path,
    redirect: (_, state) => state.extra is T ? null : fallback,
    pageBuilder: (_, state) => MaterialPage<Object?>(
      key: state.pageKey,
      fullscreenDialog: fullscreenDialog,
      child: build(state.extra as T),
    ),
  );

  /// The app's router, when it carries this page; null in a host
  /// without one or with a router of its own (a test harness).
  GoRouter? _routerFor(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return null;
    final match = router.configuration.findMatch(Uri.parse(path));
    return match.isEmpty ? null : router;
  }

  /// Opens the page for [argument]. Inside the app that is a route push;
  /// a widget pumped without the app's router (a test harness) gets the
  /// same page pushed directly.
  Future<R?> open<R>(BuildContext context, T argument) {
    final router = _routerFor(context);
    if (router != null) return router.push<R>(path, extra: argument);
    return Navigator.of(context).push<R>(
      MaterialPageRoute<R>(
        fullscreenDialog: fullscreenDialog,
        builder: (_) => build(argument),
      ),
    );
  }

  /// Opens the page for [argument] in place of the current one.
  Future<R?> replace<R>(BuildContext context, T argument) {
    final router = _routerFor(context);
    if (router != null) return router.pushReplacement<R>(path, extra: argument);
    return Navigator.of(context).pushReplacement<R, Object?>(
      MaterialPageRoute<R>(
        fullscreenDialog: fullscreenDialog,
        builder: (_) => build(argument),
      ),
    );
  }
}

/// Opens [location] — a route the router already has — or, without a
/// router (a test harness), the page [orBuild] builds.
Future<R?> openLocation<R>(
  BuildContext context,
  String location, {
  required WidgetBuilder orBuild,
}) {
  final router = GoRouter.maybeOf(context);
  if (router != null) return router.push<R>(location);
  return Navigator.of(context).push<R>(MaterialPageRoute<R>(builder: orBuild));
}
