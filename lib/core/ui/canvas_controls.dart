// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

/// Content-pixel fit rectangle from a plan's used-cell [bounds] and the
/// canvas cell size — the box [CanvasControls.fitBounds] auto-fits to view.
Rect? fitRectFromCells(
  ({int x, int y, int w, int h})? bounds,
  double cellSize,
) {
  if (bounds == null) return null;
  return Rect.fromLTWH(
    bounds.x * cellSize,
    bounds.y * cellSize,
    bounds.w * cellSize,
    bounds.h * cellSize,
  );
}

/// Zoom buttons + draggable scrollbars overlaid on an [InteractiveViewer]
/// that shares [controller]. Drop it in a Stack ABOVE the viewer, filling the
/// same box. [contentSize] is the child's unscaled size and [boundaryMargin]
/// mirrors the viewer's, so the scrollbars span exactly the pannable extent.
///
/// The viewer keeps its native pinch-zoom / drag-pan; this adds the discrete
/// controls desktop users expect and a visible sense of position.
class CanvasControls extends StatefulWidget {
  const CanvasControls({
    super.key,
    required this.controller,
    required this.contentSize,
    this.minScale = defaultMinScale,
    this.maxScale = defaultMaxScale,
    this.boundaryMargin = defaultBoundaryMargin,
    this.zoomStep = 1.4,
    this.fitBounds,
    this.fitKey,
  });

  /// Canonical zoom limits and pan margin of every plan canvas (live plan,
  /// Reserve hub, editor). The paired [InteractiveViewer] must use the same
  /// values — reference these instead of re-declaring the numbers.
  static const double defaultMinScale = 0.4;
  static const double defaultMaxScale = 3;
  static const double defaultBoundaryMargin = 200;

  final TransformationController controller;
  final Size contentSize;
  final double minScale;
  final double maxScale;
  final double boundaryMargin;

  /// Multiplier applied per zoom-in tap (its inverse for zoom-out).
  final double zoomStep;

  /// Content-pixel rectangle to auto-fit to the viewport on first layout,
  /// on a [fitKey] change (a new level) and on a viewport change (rotation).
  /// The reset button also re-fits to it. Null = no auto-fit (identity).
  final Rect? fitBounds;

  /// Identity of what [fitBounds] describes (e.g. the level id): the auto-fit
  /// runs once per key, so panning/zooming — or editing the same level — is
  /// never yanked back, but switching levels re-fits.
  final String? fitKey;

  @override
  State<CanvasControls> createState() => _CanvasControlsState();
}

class _CanvasControlsState extends State<CanvasControls> {
  static const double _thickness = 8;
  static const double _minThumb = 24;

  /// The (fitKey, viewport) the auto-fit last ran for — so it fires once per
  /// level and again on rotation, but not on every rebuild.
  String? _fittedKey;
  Size? _fittedViewport;

  double _scaleOf(Matrix4 m) => m.getMaxScaleOnAxis();

  Offset _sceneTopLeft(Matrix4 m) {
    final s = _scaleOf(m);
    final t = m.getTranslation();
    return Offset(-t.x / s, -t.y / s);
  }

  Size _sceneSpan() => Size(
        widget.contentSize.width + widget.boundaryMargin * 2,
        widget.contentSize.height + widget.boundaryMargin * 2,
      );

  Matrix4 _matrixFor(double scale, Offset topLeft, Size viewport) {
    final windowW = viewport.width / scale;
    final windowH = viewport.height / scale;
    final minX = -widget.boundaryMargin;
    final maxX = widget.contentSize.width + widget.boundaryMargin - windowW;
    final minY = -widget.boundaryMargin;
    final maxY = widget.contentSize.height + widget.boundaryMargin - windowH;
    final x = maxX < minX ? minX : topLeft.dx.clamp(minX, maxX);
    final y = maxY < minY ? minY : topLeft.dy.clamp(minY, maxY);
    return Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(-x * scale, -y * scale, 0);
  }

  void _zoomAround(double factor, Offset viewportPoint, Size viewport) {
    final old = _scaleOf(widget.controller.value);
    final next = (old * factor).clamp(widget.minScale, widget.maxScale);
    if (next == old) return;
    final anchorScene = widget.controller.toScene(viewportPoint);
    final topLeft =
        anchorScene - Offset(viewportPoint.dx, viewportPoint.dy) / next;
    widget.controller.value = _matrixFor(next, topLeft, viewport);
  }

  /// Reset = fit the content bounds when known, else identity.
  void _reset(Size viewport) {
    if (widget.fitBounds != null) {
      _applyFit(widget.fitBounds!, viewport);
    } else {
      widget.controller.value = _matrixFor(1, Offset.zero, viewport);
    }
  }

  /// Scale [bounds] (content px) to fill the viewport with a little breathing
  /// room, centred — "size the office to the screen". Not clamped to the pan
  /// bounds so a small office can sit dead-centre.
  void _applyFit(Rect bounds, Size viewport) {
    if (bounds.width <= 0 || bounds.height <= 0) return;
    const pad = 0.92;
    final scale = (viewport.width / bounds.width)
        .clamp(0.0, viewport.height / bounds.height);
    final fitted = (scale * pad).clamp(widget.minScale, widget.maxScale);
    final topLeft = bounds.center -
        Offset(viewport.width / 2, viewport.height / 2) / fitted;
    widget.controller.value = Matrix4.diagonal3Values(fitted, fitted, 1)
      ..setTranslationRaw(-topLeft.dx * fitted, -topLeft.dy * fitted, 0);
  }

  /// Fires the auto-fit once per (fitKey, viewport). Called from build; it
  /// latches synchronously (no setState) and schedules the transform for the
  /// next frame, when the viewer is laid out.
  void _maybeFit(Size viewport) {
    final bounds = widget.fitBounds;
    if (bounds == null || viewport.isEmpty) return;
    if (widget.fitKey == _fittedKey && viewport == _fittedViewport) return;
    _fittedKey = widget.fitKey;
    _fittedViewport = viewport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyFit(bounds, viewport);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        _maybeFit(viewport);
        final center = Offset(viewport.width / 2, viewport.height / 2);
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final scale = _scaleOf(controller.value);
            final tl = _sceneTopLeft(controller.value);
            final span = _sceneSpan();
            final windowW = viewport.width / scale;
            final windowH = viewport.height / scale;

            final hTrack = viewport.width - _thickness - 8;
            final vTrack = viewport.height - _thickness - 8;

            final hThumb = _thumb(
              track: hTrack,
              start: tl.dx - (-widget.boundaryMargin),
              window: windowW,
              span: span.width,
            );
            final vThumb = _thumb(
              track: vTrack,
              start: tl.dy - (-widget.boundaryMargin),
              window: windowH,
              span: span.height,
            );

            return Stack(
              children: [
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
                Positioned(
                  right: _thickness + 8,
                  bottom: _thickness + 8,
                  child: _ZoomCluster(
                    onIn: () => _zoomAround(widget.zoomStep, center, viewport),
                    onOut: () =>
                        _zoomAround(1 / widget.zoomStep, center, viewport),
                    onReset: () => _reset(viewport),
                    atMax: scale >= widget.maxScale - 1e-6,
                    atMin: scale <= widget.minScale + 1e-6,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  (double, double) _thumb({
    required double track,
    required double start,
    required double window,
    required double span,
  }) {
    if (span <= 0) return (0, track);
    final len = (window / span * track).clamp(_minThumb, track);
    final maxStart = track - len;
    final pos =
        (start / span * track).clamp(0.0, maxStart <= 0 ? 0.0 : maxStart);
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
