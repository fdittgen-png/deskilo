// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — two design languages, one app.
//
// The Me layer is the person's: DesKilo's own ink-blue, never a
// workspace's brand colour and never a workspace's development strip. A
// space is the space's: its colour, and its strip when it is a rehearsal
// space (#917). Which one a screen belongs to is decided HERE, above the
// navigator, from the route on top — so a page pushed from Me (Linked
// accounts, Privacy, a public space page) wears the Me layer too, and
// nobody has to remember to theme it.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../route_classes.dart';
import '../theme.dart';
import 'development_banner.dart';

/// Whether [path] is the person's own layer rather than a space's: every
/// registered route that needs no membership.
bool isMeLayer(String path) => switch (classifyRoute(path)) {
      RouteClass.publicEntry ||
      RouteClass.nativeAccount ||
      RouteClass.operator =>
        true,
      RouteClass.workspace || RouteClass.unknown => false,
    };

class LayerChrome extends StatefulWidget {
  const LayerChrome({
    super.key,
    required this.router,
    required this.animations,
    required this.child,
  });

  final GoRouter router;
  final bool animations;
  final Widget child;

  @override
  State<LayerChrome> createState() => _LayerChromeState();
}

class _LayerChromeState extends State<LayerChrome> {
  late bool _me = _isMe();

  bool _isMe() {
    final delegate = widget.router.routerDelegate;
    return delegate.currentConfiguration.isNotEmpty &&
        isMeLayer(widget.router.state.uri.path);
  }

  /// The delegate announces a route while the Router itself is building,
  /// so the layer is re-read after that frame rather than inside it.
  void _routed() {
    if (_isMe() == _me) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isMe() != _me) setState(() => _me = !_me);
    });
  }

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_routed);
  }

  @override
  void didUpdateWidget(LayerChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_routed);
      widget.router.routerDelegate.addListener(_routed);
      _me = _isMe();
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_routed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // One structure for both layers: switching changes the theme's data
    // and the strip, never the element tree the navigator lives in.
    final ambient = Theme.of(context);
    final dark = ambient.brightness == Brightness.dark;
    return Theme(
      data: !_me
          ? ambient
          : dark
              ? DeskiloTheme.dark(
                  animations: widget.animations, brand: DeskiloTheme.meLayerSeed)
              : DeskiloTheme.light(
                  animations: widget.animations, brand: DeskiloTheme.meLayerSeed),
      child: DevelopmentBanner(hidden: _me, child: widget.child),
    );
  }
}
