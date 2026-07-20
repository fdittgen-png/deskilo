// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

/// Zoom buttons + draggable scrollbars overlaid on an [InteractiveViewer]
/// that shares [controller]. Drop it in a Stack ABOVE the viewer, filling the
/// same box. [contentSize] is the child's unscaled size and [boundaryMargin]
/// mirrors the viewer's, so the scrollbars span exactly the pannable extent.
///
/// The viewer keeps its native pinch-zoom / drag-pan; this adds the discrete
/// controls desktop users expect and a visible sense of position.
class CanvasControls extends StatelessWidget {
  const CanvasControls({
    super.key,
    required this.controller,
    required this.contentSize,
    this.minScale = 0.4,
    this.maxScale = 3,
    this.boundaryMargin = 200,
    this.zoomStep = 1.4,
  });

  final TransformationController controller;
  final Size contentSize;
  final double minScale;
  final double maxScale;
  final double boundaryMargin;

  /// Multiplier applied per zoom-in tap (its inverse for zoom-out).
  final double zoomStep;

  static const double _thickness = 8;
  static const double _minThumb = 24;

  double _scaleOf(Matrix4 m) => m.getMaxScaleOnAxis();

  Offset _sceneTopLeft(Matrix4 m) {
    final s = _scaleOf(m);
    final t = m.getTranslation();
    return Offset(-t.x / s, -t.y / s);
  }

  /// Total pannable span in scene units (content plus the margin on each side).
  Size _sceneSpan() => Size(
        contentSize.width + boundaryMargin * 2,
        contentSize.height + boundaryMargin * 2,
      );

  Matrix4 _matrixFor(double scale, Offset topLeft, Size viewport) {
    // Clamp so the visible window stays within [-margin, content + margin].
    final windowW = viewport.width / scale;
    final windowH = viewport.height / scale;
    final minX = -boundaryMargin;
    final maxX = contentSize.width + boundaryMargin - windowW;
    final minY = -boundaryMargin;
    final maxY = contentSize.height + boundaryMargin - windowH;
    final x = maxX < minX ? minX : topLeft.dx.clamp(minX, maxX);
    final y = maxY < minY ? minY : topLeft.dy.clamp(minY, maxY);
    // A pure scale + translate: scene p → scale*p + t (no rotation), the
    // exact shape InteractiveViewer keeps.
    return Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(-x * scale, -y * scale, 0);
  }

  void _zoomAround(double factor, Offset viewportPoint, Size viewport) {
    final old = _scaleOf(controller.value);
    final next = (old * factor).clamp(minScale, maxScale);
    if (next == old) return;
    final anchorScene = controller.toScene(viewportPoint);
    final topLeft = anchorScene - Offset(viewportPoint.dx, viewportPoint.dy) / next;
    controller.value = _matrixFor(next, topLeft, viewport);
  }

  void _reset(Size viewport) {
    controller.value = _matrixFor(1, Offset.zero, viewport);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final center = Offset(viewport.width / 2, viewport.height / 2);
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final scale = _scaleOf(controller.value);
            final tl = _sceneTopLeft(controller.value);
            final span = _sceneSpan();
            final windowW = viewport.width / scale;
            final windowH = viewport.height / scale;

            // Track lengths leave room for the perpendicular bar at the corner.
            final hTrack = viewport.width - _thickness - 8;
            final vTrack = viewport.height - _thickness - 8;

            final hThumb = _thumb(
              track: hTrack,
              start: tl.dx - (-boundaryMargin),
              window: windowW,
              span: span.width,
            );
            final vThumb = _thumb(
              track: vTrack,
              start: tl.dy - (-boundaryMargin),
              window: windowH,
              span: span.height,
            );

            return Stack(
              children: [
                // Horizontal scrollbar along the bottom.
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: _Scrollbar(
                    horizontal: true,
                    trackLength: hTrack,
                    thickness: _thickness,
                    thumbStart: hThumb.$1,
                    thumbLength: hThumb.$2,
                    color: scheme.onSurfaceVariant,
                    onDrag: (delta) {
                      final ds = delta / hTrack * span.width;
                      controller.value = _matrixFor(
                        scale,
                        Offset(tl.dx + ds, tl.dy),
                        viewport,
                      );
                    },
                  ),
                ),
                // Vertical scrollbar along the right edge.
                Positioned(
                  top: 0,
                  right: 0,
                  child: _Scrollbar(
                    horizontal: false,
                    trackLength: vTrack,
                    thickness: _thickness,
                    thumbStart: vThumb.$1,
                    thumbLength: vThumb.$2,
                    color: scheme.onSurfaceVariant,
                    onDrag: (delta) {
                      final ds = delta / vTrack * span.height;
                      controller.value = _matrixFor(
                        scale,
                        Offset(tl.dx, tl.dy + ds),
                        viewport,
                      );
                    },
                  ),
                ),
                // Zoom cluster, clear of both scrollbars.
                Positioned(
                  right: _thickness + 8,
                  bottom: _thickness + 8,
                  child: _ZoomCluster(
                    onIn: () => _zoomAround(zoomStep, center, viewport),
                    onOut: () => _zoomAround(1 / zoomStep, center, viewport),
                    onReset: () => _reset(viewport),
                    atMax: scale >= maxScale - 1e-6,
                    atMin: scale <= minScale + 1e-6,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// (start px, length px) of a thumb on a track of [track] px, given the
  /// visible [window] starting at [start] within a total [span] (scene units).
  (double, double) _thumb({
    required double track,
    required double start,
    required double window,
    required double span,
  }) {
    if (span <= 0) return (0, track);
    final len = (window / span * track).clamp(_minThumb, track);
    final maxStart = track - len;
    final pos = (start / span * track).clamp(0.0, maxStart <= 0 ? 0.0 : maxStart);
    return (pos, len);
  }
}

class _Scrollbar extends StatelessWidget {
  const _Scrollbar({
    required this.horizontal,
    required this.trackLength,
    required this.thickness,
    required this.thumbStart,
    required this.thumbLength,
    required this.color,
    required this.onDrag,
  });

  final bool horizontal;
  final double trackLength;
  final double thickness;
  final double thumbStart;
  final double thumbLength;
  final Color color;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final thumb = Positioned(
      left: horizontal ? thumbStart : 0,
      top: horizontal ? 0 : thumbStart,
      child: GestureDetector(
        onHorizontalDragUpdate:
            horizontal ? (d) => onDrag(d.delta.dx) : null,
        onVerticalDragUpdate: horizontal ? null : (d) => onDrag(d.delta.dy),
        child: Container(
          width: horizontal ? thumbLength : thickness,
          height: horizontal ? thickness : thumbLength,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.55),
            borderRadius: AppRadius.smAll,
          ),
        ),
      ),
    );
    return SizedBox(
      width: horizontal ? trackLength : thickness,
      height: horizontal ? thickness : trackLength,
      child: Stack(children: [thumb]),
    );
  }
}

class _ZoomCluster extends StatelessWidget {
  const _ZoomCluster({
    required this.onIn,
    required this.onOut,
    required this.onReset,
    required this.atMax,
    required this.atMin,
  });

  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onReset;
  final bool atMax;
  final bool atMin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget button(IconData icon, VoidCallback? onTap, String key) => Material(
          color: scheme.surfaceContainerHighest,
          child: InkWell(
            key: ValueKey(key),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                icon,
                size: 22,
                color: onTap == null
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                    : scheme.onSurface,
              ),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.add, atMax ? null : onIn, 'canvas-zoom-in'),
          Divider(height: 1, color: scheme.outlineVariant),
          button(Icons.remove, atMin ? null : onOut, 'canvas-zoom-out'),
          Divider(height: 1, color: scheme.outlineVariant),
          button(Icons.center_focus_strong_outlined, onReset, 'canvas-zoom-reset'),
        ],
      ),
    );
  }
}
