// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — entering a space is something you see happen.
//
// The card you tapped grows to fill the screen in the space's colour,
// carrying its name, and the space opens beneath it; then the curtain
// lifts. The whole thing is one finite animation on the root overlay, so
// it survives the route change it covers. With motion off — the
// `uiAnimations` flag or the platform's reduced-motion setting — there
// is no curtain at all and the space simply opens.
//
// #2313 — the curtain wears the space's identity when its owner chose
// one (the space's OWN branding flag): its colour drawn in its pattern,
// and its logo above the name, held a moment so it can be read. The
// logo is the one already loaded for its avatar; the entry never waits
// for a download.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../route_classes.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/workspace/domain/workspace.dart';
import '../../features/workspace/domain/workspace_branding.dart';
import '../../features/workspace/presentation/widgets/brand_swatch.dart';
import '../../features/workspace/providers/workspace_providers.dart';

/// Enter [space]: it becomes this person's space (and their next start),
/// the curtain plays from [from] when motion is on, and the space opens.
Future<void> enterSpace(
  BuildContext context,
  WidgetRef ref,
  Workspace space, {
  Rect? from,
}) async {
  final router = GoRouter.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  final animate = MotionSettings.enabledOf(context);
  final brand = spaceBrand(space);
  final colour = brand?.color ?? Theme.of(context).colorScheme.tertiary;
  final logo = brandingOn(space)
      ? ref.read(workspaceEmblemOfProvider(space.id)).value
      : null;
  await ref.read(activeWorkspaceIdProvider.notifier).select(space.id);
  if (!animate) {
    router.go(kDefaultHome);
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SpaceCurtain(
      name: space.name,
      colour: colour,
      pattern: brand?.pattern,
      logo: logo,
      from: from,
      onCovered: () => router.go(kDefaultHome),
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _SpaceCurtain extends StatefulWidget {
  const _SpaceCurtain({
    required this.name,
    required this.colour,
    this.pattern,
    this.logo,
    required this.from,
    required this.onCovered,
    required this.onDone,
  });

  final String name;
  final Color colour;
  final BrandPattern? pattern;

  /// The space's logo (its emblem), when one is loaded.
  final Uint8List? logo;
  final Rect? from;
  final VoidCallback onCovered;
  final VoidCallback onDone;

  @override
  State<_SpaceCurtain> createState() => _SpaceCurtainState();
}

class _SpaceCurtainState extends State<_SpaceCurtain>
    with TickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: MotionTokens.emphasized,
  );
  // A logo is held on screen long enough to be read; an animation, not a
  // timer, so it runs on frames like the rest of the curtain.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  bool _lifting = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _grow.forward();
    if (!mounted) return;
    widget.onCovered();
    if (widget.logo != null) await _hold.forward();
    if (!mounted) return;
    setState(() => _lifting = true);
  }

  @override
  void dispose() {
    _grow.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final full = Offset.zero & size;
    final start = widget.from ?? full.deflate(size.shortestSide / 4);
    final on = ThemeData.estimateBrightnessForColor(widget.colour) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
    return AnimatedOpacity(
      key: const ValueKey('space-entry-curtain'),
      opacity: _lifting ? 0 : 1,
      duration: MotionTokens.quick,
      onEnd: widget.onDone,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _grow,
          builder: (context, child) {
            final t = MotionTokens.enter.transform(_grow.value);
            final rect = Rect.lerp(start, full, t)!;
            return Stack(children: [
              Positioned.fromRect(
                rect: rect,
                child: BrandSwatch(
                  key: const ValueKey('space-entry-fill'),
                  color: widget.colour,
                  pattern: widget.pattern,
                  borderRadius: BorderRadius.lerp(
                      AppRadius.lgAll, BorderRadius.zero, t),
                  child: child,
                ),
              ),
            ]);
          },
          child: Center(
            child: Padding(
              padding: AppSpacing.mdAll,
              // Scaled down while the curtain is still the size of the card
              // it grows from.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.logo case final bytes?) ...[
                      // On a light card, so a logo drawn for white paper
                      // reads on any colour.
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.lgAll,
                        ),
                        child: Padding(
                          padding: AppSpacing.mdAll,
                          child: Image.memory(
                            bytes,
                            key: const ValueKey('space-entry-logo'),
                            height: 96,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(
                      widget.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: on),
                    ),
                  ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
