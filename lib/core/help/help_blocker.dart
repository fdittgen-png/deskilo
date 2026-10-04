// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — a real blocker on screen tells the help arbiter so.
//
// Wrap whatever the person must resolve first (a closed-day banner, a
// refusal that stays visible) in a [HelpBlocker]: while it is mounted the
// arbiter's slot is [HelpSlot.blocker], so tips stay silent and a guided
// task shrinks to a "resolve this first" notice. Unmounting clears it.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'help_arbiter.dart';

class HelpBlocker extends ConsumerStatefulWidget {
  const HelpBlocker({super.key, required this.id, required this.child});

  /// Stable id of the blocker, unique among the blockers of a screen.
  final String id;
  final Widget child;

  @override
  ConsumerState<HelpBlocker> createState() => _HelpBlockerState();
}

class _HelpBlockerState extends ConsumerState<HelpBlocker> {
  late final HelpArbiter _arbiter = ref.read(helpArbiterProvider.notifier);
  late final String _id = widget.id;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    // Provider state may not change while the tree is building.
    Future.microtask(() {
      if (_mounted) _arbiter.blockerShown(_id);
    });
  }

  @override
  void dispose() {
    _mounted = false;
    Future.microtask(() => _arbiter.blockerCleared(_id));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
