// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

/// A horizontally scrolling row that SAYS it scrolls (#1184).
///
/// Four screens ended a filter row on a chip sliced in half by the
/// screen edge — Alerts, the Agenda, and the report editor twice. The
/// rows did scroll; nothing on them said so, and a bisected chip reads
/// as a rendering fault rather than as "there is more this way".
///
/// The answer is the one every platform uses: fade the content out at
/// the edge it continues past. It is unambiguous (a chip that dissolves
/// was clearly not meant to end there), it costs no room, and unlike an
/// arrow it does not need a hit target or a label.
///
/// The fade appears only on a side that actually has more — no fade at
/// rest on a row that fits, and none at the end once you have scrolled
/// there — so its presence is information rather than decoration.
class EdgeFadeScroll extends StatefulWidget {
  const EdgeFadeScroll({
    super.key,
    required Widget this.child,
    this.padding,
    this.controller,
  }) : builder = null;

  /// For a caller that builds its OWN scrollable — a lazy `ListView`
  /// over forty placeholder chips, say, where a `Row` would build all
  /// forty. The builder MUST attach the controller it is handed, or
  /// there are no metrics to fade from.
  const EdgeFadeScroll.around({
    super.key,
    required Widget Function(BuildContext, ScrollController) this.builder,
  })  : child = null,
        padding = null,
        controller = null;

  /// Usually a `Row` of chips.
  final Widget? child;

  final Widget Function(BuildContext, ScrollController)? builder;

  /// Inset for the content. The horizontal half also gives the last
  /// chip room to clear the edge instead of touching it.
  final EdgeInsetsGeometry? padding;

  final ScrollController? controller;

  /// How wide the dissolve is. Narrow enough not to grey a whole chip,
  /// wide enough to read as a fade rather than a hard crop.
  static const double fadeWidth = 24;

  @override
  State<EdgeFadeScroll> createState() => _EdgeFadeScrollState();
}

class _EdgeFadeScrollState extends State<EdgeFadeScroll> {
  late final ScrollController _controller =
      widget.controller ?? ScrollController();
  bool _more = false;
  bool _before = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
    // The first frame is the one that knows whether the row overflows:
    // before layout there are no metrics to ask.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _controller.removeListener(_sync);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    // A pixel of tolerance: a fractional overscroll at the end is not
    // "there is more", and a fade that flickers there is worse than no
    // fade at all.
    final more = position.pixels < position.maxScrollExtent - 1;
    final before = position.pixels > position.minScrollExtent + 1;
    if (more != _more || before != _before) {
      setState(() {
        _more = more;
        _before = before;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scroll = NotificationListener<ScrollMetricsNotification>(
      // Fires when the CONTENT changes size — a filter that removes
      // chips can end the overflow without anybody scrolling.
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
        return false;
      },
      child: widget.builder?.call(context, _controller) ??
          SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            child: widget.child!,
          ),
    );
    if (!_more && !_before) return scroll;
    const fade = EdgeFadeScroll.fadeWidth;
    return ShaderMask(
      // dstIn keeps the child's colours and takes only the gradient's
      // alpha, so the chips fade into whatever is behind the row rather
      // than into a colour this widget would have to guess.
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final width = bounds.width;
        if (width <= 0) {
          return const LinearGradient(
            colors: [Colors.white, Colors.white],
          ).createShader(bounds);
        }
        final stop = (fade / width).clamp(0.0, 0.5);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _before ? Colors.transparent : Colors.white,
            Colors.white,
            Colors.white,
            _more ? Colors.transparent : Colors.white,
          ],
          stops: [0, stop, 1 - stop, 1],
        ).createShader(bounds);
      },
      child: scroll,
    );
  }
}
