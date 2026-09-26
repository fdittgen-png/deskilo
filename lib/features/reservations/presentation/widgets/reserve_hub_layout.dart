// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/ui/motion.dart';
import 'reserve_view_menu.dart';

/// The plan retains space while guidance and controls scroll at large text.
/// Landscape keeps the existing side panel; neither layout clips actions.
class ReserveHubLayout extends StatelessWidget {
  const ReserveHubLayout({super.key, required this.header, required this.view,
    required this.buildView});
  final Widget header;
  final ReserveView view;
  final Widget Function(ReserveView view) buildView;

  @override
  Widget build(BuildContext context) {
    final content = Expanded(child: AnimatedSwitcher(
      duration: AppMotion.viewSwitchOf(context),
      switchInCurve: MotionTokens.enter,
      switchOutCurve: MotionTokens.ease,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation,
        child: ScaleTransition(scale: Tween<double>(begin: 0.97, end: 1)
            .animate(animation), child: child)),
      child: KeyedSubtree(
        key: switch (view) {
          ReserveView.plan || ReserveView.list => const ValueKey('reserve-plan-view'),
          ReserveView.day => const ValueKey('reserve-day-view'),
          ReserveView.week => const ValueKey('reserve-week-view'),
          ReserveView.month => const ValueKey('reserve-month-view'),
        },
        child: buildView(view)),
    ));
    return Scaffold(body: LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > constraints.maxHeight) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: (constraints.maxWidth * 0.3).clamp(260.0, 380.0),
            child: SingleChildScrollView(child: header)),
          const VerticalDivider(key: ValueKey('split-divider'), width: 1),
          content,
        ]);
      }
      return Column(children: [
        Flexible(child: SingleChildScrollView(
          key: const ValueKey('reserve-header-scroll'), child: header)),
        content,
      ]);
    }));
  }
}
