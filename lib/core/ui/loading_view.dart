// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import 'motion.dart';

/// Centered progress indicator behind a short fade-in (#209): the spinner
/// starts fully transparent and fades in over [AppMotion.loadingFadeIn]
/// after the first frame, so loads that resolve quickly never flash a
/// spinner at all.
///
/// Drop-in replacement for the bare
/// `Center(child: CircularProgressIndicator())` idiom — same layout.
class LoadingView extends StatefulWidget {
  const LoadingView({super.key});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Post-frame, not immediate: the first frame must render at opacity 0
    // for the implicit animation to have a start state to fade from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: AppMotion.loadingFadeIn,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
