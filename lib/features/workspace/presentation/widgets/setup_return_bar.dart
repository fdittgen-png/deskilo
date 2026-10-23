// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 (ADR 0047 §6) — a screen opened from the setup guide carries a
// "Back to the setup guide" bar, whatever screen it is and however deep the
// owner went from there. The guide raises the flag while one of its steps
// is open and lowers it on the way back; the bar sits above the navigator,
// so no settings screen has to know it was opened from the guide.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

part 'setup_return_bar.g.dart';

/// Whether a step of the setup guide is open over the guide.
@Riverpod(keepAlive: true)
class SetupReturnPending extends _$SetupReturnPending {
  @override
  bool build() => false;

  void set({required bool open}) => state = open;
}

/// [child], with the way back to the guide under it while a step is open.
class SetupReturnBar extends ConsumerStatefulWidget {
  const SetupReturnBar({required this.router, required this.child, super.key});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<SetupReturnBar> createState() => _SetupReturnBarState();
}

class _SetupReturnBarState extends ConsumerState<SetupReturnBar> {
  late bool _onGuide = _guideOnTop();

  /// #2912 — the TOP route's own location, never the reported one: that
  /// is the route under a push, /reserve when the guide was pushed over
  /// Reserve.
  bool _guideOnTop() =>
      widget.router.routerDelegate.currentConfiguration.isNotEmpty &&
      widget.router.state.uri.path == '/setup';

  /// The delegate announces a route while the Router itself is building,
  /// so the top route is re-read after that frame rather than inside it.
  void _routed() {
    if (_guideOnTop() == _onGuide) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _guideOnTop() != _onGuide) {
        setState(() => _onGuide = !_onGuide);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_routed);
  }

  @override
  void didUpdateWidget(SetupReturnBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_routed);
      widget.router.routerDelegate.addListener(_routed);
      _onGuide = _guideOnTop();
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_routed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(setupReturnPendingProvider);
    // One shape whether the bar shows or not: a parent of the Router that
    // changes type rebuilds the Router, which restores the stack from the
    // location last reported, so a step just closed by Back opened again.
    return Column(
      children: [
        Expanded(child: widget.child),
        if (pending && !_onGuide)
          Material(
            key: const ValueKey('setup-return-bar'),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('setup-return'),
                    icon: const Icon(Icons.checklist_outlined),
                    label: Text(context.l10n.setupGuideReturn),
                    // Going there drops the step page, whose push then never
                    // answers: the way back is taken, so the bar goes too.
                    onPressed: () {
                      ref.read(setupReturnPendingProvider.notifier).set(open: false);
                      widget.router.go('/setup');
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
