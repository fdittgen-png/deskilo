// SPDX-License-Identifier: 0BSD
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_mode.dart';

/// #970 — the blur above the whole app. While demo mode is on, after
/// every frame it walks the render tree under it, collects the
/// rectangle of every paragraph and every text field whose text carries
/// a registered personal string, and paints a backdrop blur clipped to
/// those rectangles. The text underneath is the real one: nothing is
/// hidden, nothing is invented, and the layout does not move.
class DemoBlurLayer extends ConsumerStatefulWidget {
  const DemoBlurLayer({super.key, required this.child});

  final Widget child;

  /// The rectangles blurred on the last frame, for tests.
  static List<Rect> get debugRects => List.unmodifiable(_lastRects);
  static List<Rect> _lastRects = const [];

  @override
  ConsumerState<DemoBlurLayer> createState() => _DemoBlurLayerState();
}

class _DemoBlurLayerState extends ConsumerState<DemoBlurLayer> {
  final _childKey = GlobalKey();
  List<Rect> _rects = const [];
  bool _scanScheduled = false;

  @override
  void initState() {
    super.initState();
    demoSensitive.addListener(_scheduleScan);
  }

  @override
  void dispose() {
    demoSensitive.removeListener(_scheduleScan);
    super.dispose();
  }

  void _scheduleScan() {
    if (_scanScheduled) return;
    _scanScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scanScheduled = false;
      if (mounted) _scan();
    });
  }

  void _scan() {
    final on = ref.read(demoModeControllerProvider).value ?? false;
    final layerBox = context.findRenderObject();
    final root = _childKey.currentContext?.findRenderObject();
    if (!on || layerBox is! RenderBox || root == null) {
      if (_rects.isNotEmpty) setState(() => _rects = const []);
      DemoBlurLayer._lastRects = const [];
      return;
    }
    final found = <Rect>[];
    void visit(RenderObject node) {
      final text = switch (node) {
        RenderParagraph p => p.text.toPlainText(),
        RenderEditable e => e.text?.toPlainText() ?? '',
        _ => null,
      };
      if (text != null) {
        if (node is RenderBox &&
            node.hasSize &&
            node.attached &&
            demoSensitive.matches(text)) {
          final origin = node.localToGlobal(Offset.zero, ancestor: layerBox);
          found.add((origin & node.size).inflate(2));
        }
        return; // a paragraph's children are its own spans
      }
      node.visitChildren(visit);
    }

    visit(root);
    DemoBlurLayer._lastRects = found;
    if (!_sameRects(found, _rects)) setState(() => _rects = found);
  }

  static bool _sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(demoModeControllerProvider).value ?? false;
    if (on) _scheduleScan();
    final child = KeyedSubtree(key: _childKey, child: widget.child);
    if (!on) {
      DemoBlurLayer._lastRects = const [];
      return child;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        // Rescans ride the frames the app produces anyway (scrolls,
        // rebuilds): a frame with no change costs one tree walk.
        Positioned.fill(
          child: IgnorePointer(
            child: _BlurRects(rects: _rects, onFrame: _scheduleScan),
          ),
        ),
      ],
    );
  }
}

class _BlurRects extends StatelessWidget {
  const _BlurRects({required this.rects, required this.onFrame});

  final List<Rect> rects;
  final VoidCallback onFrame;

  @override
  Widget build(BuildContext context) {
    // Every frame the layer paints, the next scan is booked — so a
    // scroll under the blur moves the blur with it.
    onFrame();
    if (rects.isEmpty) return const SizedBox.shrink();
    return ClipPath(
      clipper: _RectsClipper(rects),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: ColoredBox(
          // A whisper of the surface over the blur: the smear reads as
          // deliberate, not as a rendering fault.
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

class _RectsClipper extends CustomClipper<Path> {
  const _RectsClipper(this.rects);

  final List<Rect> rects;

  @override
  Path getClip(Size size) {
    final path = Path();
    for (final r in rects) {
      path.addRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)));
    }
    return path;
  }

  @override
  bool shouldReclip(_RectsClipper oldClipper) => oldClipper.rects != rects;
}
